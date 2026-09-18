/* Piano playback.
 *
 * Preference order, decided once per session and reported to the user:
 *   1. a General MIDI acoustic grand soundfont vendored under /soundfonts/
 *      (run tools/fetch_soundfont.py to put it there)
 *   2. the same soundfont from its public CDN
 *   3. a built-in additive synth, so the app still makes a sound offline
 *
 * The generator's output is a note list, not a MIDI file to be re-parsed, so
 * playback schedules exactly the notes that were written - nothing is inferred
 * back out of a rendered file.
 */
(function (global) {
  'use strict';

  var SOUNDFONT_SOURCES = [
    '/soundfonts/acoustic_grand_piano-mp3.js',
    'https://gleitz.github.io/midi-js-soundfonts/FluidR3_GM/acoustic_grand_piano-mp3.js'
  ];

  var NOTE_OFFSETS = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
  var RELEASE = 0.28;

  function noteNameToMidi(name) {
    var match = /^([A-G])(#|b)?(-?\d)$/.exec(name);
    if (!match) { return null; }
    var pitch = NOTE_OFFSETS[match[1]];
    if (match[2] === '#') { pitch += 1; }
    if (match[2] === 'b') { pitch -= 1; }
    return pitch + (parseInt(match[3], 10) + 1) * 12;
  }

  function base64ToArrayBuffer(dataUri) {
    var base64 = dataUri.slice(dataUri.indexOf(',') + 1);
    var binary = global.atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) { bytes[i] = binary.charCodeAt(i); }
    return bytes.buffer;
  }

  function PianoPlayer() {
    this.context = null;
    this.samples = null;        // midi note -> encoded ArrayBuffer
    this.buffers = {};          // midi note -> decoded AudioBuffer
    this.voice = 'none';
    this.active = [];
    this.startedAt = 0;
    this.duration = 0;
  }

  PianoPlayer.prototype.ensureContext = function () {
    if (!this.context) {
      var Ctor = global.AudioContext || global.webkitAudioContext;
      this.context = new Ctor();
    }
    if (this.context.state === 'suspended') { this.context.resume(); }
    return this.context;
  };

  PianoPlayer.prototype.loadVoice = function () {
    var self = this;
    if (this.voicePromise) { return this.voicePromise; }

    this.voicePromise = (function attempt(index) {
      if (index >= SOUNDFONT_SOURCES.length) {
        self.voice = 'synth';
        return Promise.resolve('synth');
      }
      return fetch(SOUNDFONT_SOURCES[index])
        .then(function (response) {
          if (!response.ok) { throw new Error('HTTP ' + response.status); }
          return response.text();
        })
        .then(function (text) {
          // The soundfont ships as `MIDI.Soundfont.x = { "A0": "data:...", ... }`.
          // Slice out the object and parse it rather than evaluating the file.
          var open = text.indexOf('{');
          var close = text.lastIndexOf('}');
          if (open < 0 || close < open) { throw new Error('unrecognised soundfont'); }
          var table = JSON.parse(text.slice(open, close + 1));
          self.samples = {};
          Object.keys(table).forEach(function (name) {
            var midi = noteNameToMidi(name);
            if (midi !== null) { self.samples[midi] = table[name]; }
          });
          if (!Object.keys(self.samples).length) { throw new Error('no samples'); }
          self.voice = 'soundfont';
          return 'soundfont';
        })
        .catch(function () { return attempt(index + 1); });
    }(0));

    return this.voicePromise;
  };

  PianoPlayer.prototype.decode = function (pitches) {
    var self = this;
    var context = this.ensureContext();
    if (this.voice !== 'soundfont') { return Promise.resolve(); }

    var wanted = pitches.filter(function (pitch) {
      return self.samples[pitch] && !self.buffers[pitch];
    });
    return Promise.all(wanted.map(function (pitch) {
      return new Promise(function (resolve) {
        var encoded = base64ToArrayBuffer(self.samples[pitch]);
        var done = function (buffer) { self.buffers[pitch] = buffer; resolve(); };
        var failed = function () { resolve(); };
        var result = context.decodeAudioData(encoded, done, failed);
        if (result && typeof result.then === 'function') { result.then(done, failed); }
      });
    }));
  };

  /* A plain additive piano-ish tone: three partials under one decay. Not a
   * piano, but enough to hear the notes when no soundfont is reachable. */
  PianoPlayer.prototype.playSynth = function (pitch, at, duration, gainValue) {
    var context = this.context;
    var frequency = 440 * Math.pow(2, (pitch - 69) / 12);
    var envelope = context.createGain();
    envelope.connect(context.destination);
    envelope.gain.setValueAtTime(0.0001, at);
    envelope.gain.exponentialRampToValueAtTime(gainValue, at + 0.012);
    envelope.gain.exponentialRampToValueAtTime(gainValue * 0.28, at + 0.35);
    envelope.gain.exponentialRampToValueAtTime(0.0001, at + duration + RELEASE);

    [[1, 1], [2, 0.32], [3, 0.12]].forEach(function (partial) {
      var oscillator = context.createOscillator();
      var level = context.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.value = frequency * partial[0];
      level.gain.value = partial[1];
      oscillator.connect(level).connect(envelope);
      oscillator.start(at);
      oscillator.stop(at + duration + RELEASE + 0.05);
      this.active.push(oscillator);
    }, this);
  };

  // Channel 10 is a kit, not a keyboard: playing note 36 as a piano C2 is the
  // one thing this project exists to avoid. Until there are drum samples, the
  // kit is synthesised — a pitched thump for the drums, filtered noise for the
  // cymbals — which is honest about being a placeholder and still keeps time.
  var DRUM_VOICES = {
    36: { type: 'tone', frequency: 55, decay: 0.28, gain: 1.0 },
    35: { type: 'tone', frequency: 48, decay: 0.32, gain: 1.0 },
    38: { type: 'noise', frequency: 1900, decay: 0.16, gain: 0.7, body: 190 },
    40: { type: 'noise', frequency: 2100, decay: 0.14, gain: 0.7, body: 210 },
    37: { type: 'noise', frequency: 2600, decay: 0.06, gain: 0.4, body: 420 },
    39: { type: 'noise', frequency: 1500, decay: 0.16, gain: 0.6 },
    42: { type: 'noise', frequency: 8000, decay: 0.045, gain: 0.34 },
    44: { type: 'noise', frequency: 6500, decay: 0.06, gain: 0.30 },
    46: { type: 'noise', frequency: 7000, decay: 0.34, gain: 0.34 },
    49: { type: 'noise', frequency: 5200, decay: 1.10, gain: 0.40 },
    55: { type: 'noise', frequency: 6200, decay: 0.70, gain: 0.36 },
    51: { type: 'noise', frequency: 7600, decay: 0.42, gain: 0.26 },
    53: { type: 'noise', frequency: 5400, decay: 0.50, gain: 0.32 },
    41: { type: 'tone', frequency: 110, decay: 0.34, gain: 0.8 },
    47: { type: 'tone', frequency: 160, decay: 0.30, gain: 0.8 },
    50: { type: 'tone', frequency: 220, decay: 0.28, gain: 0.8 },
    54: { type: 'noise', frequency: 5000, decay: 0.22, gain: 0.30 },
    56: { type: 'tone', frequency: 800, decay: 0.16, gain: 0.5 },
    64: { type: 'tone', frequency: 190, decay: 0.24, gain: 0.7 },
    63: { type: 'tone', frequency: 260, decay: 0.20, gain: 0.7 },
    75: { type: 'tone', frequency: 2400, decay: 0.09, gain: 0.5 },
    76: { type: 'tone', frequency: 1200, decay: 0.09, gain: 0.5 },
    82: { type: 'noise', frequency: 9000, decay: 0.07, gain: 0.22 },
    69: { type: 'noise', frequency: 7000, decay: 0.10, gain: 0.22 },
    70: { type: 'noise', frequency: 8500, decay: 0.06, gain: 0.22 },
    67: { type: 'tone', frequency: 900, decay: 0.14, gain: 0.5 },
    65: { type: 'tone', frequency: 340, decay: 0.16, gain: 0.6 },
    81: { type: 'tone', frequency: 3200, decay: 0.60, gain: 0.30 }
  };

  var DEFAULT_DRUM = { type: 'noise', frequency: 4000, decay: 0.12, gain: 0.3 };

  PianoPlayer.prototype.noiseBuffer = function () {
    if (this.noise) { return this.noise; }
    var context = this.context;
    var length = Math.floor(context.sampleRate * 1.2);
    var buffer = context.createBuffer(1, length, context.sampleRate);
    var data = buffer.getChannelData(0);
    for (var i = 0; i < length; i += 1) { data[i] = Math.random() * 2 - 1; }
    this.noise = buffer;
    return buffer;
  };

  PianoPlayer.prototype.playDrum = function (pitch, at, gainValue) {
    var context = this.context;
    var voice = DRUM_VOICES[pitch] || DEFAULT_DRUM;
    var level = gainValue * voice.gain;
    var envelope = context.createGain();
    envelope.connect(context.destination);
    envelope.gain.setValueAtTime(Math.max(0.0001, level), at);
    envelope.gain.exponentialRampToValueAtTime(0.0001, at + voice.decay);

    if (voice.type === 'noise') {
      var source = context.createBufferSource();
      source.buffer = this.noiseBuffer();
      var filter = context.createBiquadFilter();
      filter.type = voice.body ? 'bandpass' : 'highpass';
      filter.frequency.value = voice.frequency;
      filter.Q.value = voice.body ? 0.8 : 0.7;
      source.connect(filter).connect(envelope);
      source.start(at);
      source.stop(at + voice.decay + 0.05);
      this.active.push(source);
      if (voice.body) {                       // a snare has a drum under it
        var tone = context.createOscillator();
        var toneLevel = context.createGain();
        tone.type = 'triangle';
        tone.frequency.setValueAtTime(voice.body, at);
        toneLevel.gain.value = 0.5;
        tone.connect(toneLevel).connect(envelope);
        tone.start(at);
        tone.stop(at + voice.decay + 0.05);
        this.active.push(tone);
      }
      return;
    }

    var oscillator = context.createOscillator();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(voice.frequency * 2.2, at);
    oscillator.frequency.exponentialRampToValueAtTime(
      voice.frequency, at + Math.min(0.08, voice.decay));
    oscillator.connect(envelope);
    oscillator.start(at);
    oscillator.stop(at + voice.decay + 0.05);
    this.active.push(oscillator);
  };

  PianoPlayer.prototype.playSample = function (pitch, at, duration, gainValue) {
    var context = this.context;
    var buffer = this.buffers[pitch];
    if (!buffer) { return this.playSynth(pitch, at, duration, gainValue); }
    var source = context.createBufferSource();
    var envelope = context.createGain();
    source.buffer = buffer;
    envelope.gain.setValueAtTime(gainValue, at);
    envelope.gain.setValueAtTime(gainValue, at + duration);
    envelope.gain.exponentialRampToValueAtTime(0.0001, at + duration + RELEASE);
    source.connect(envelope).connect(context.destination);
    source.start(at);
    source.stop(at + duration + RELEASE + 0.05);
    this.active.push(source);
    return null;
  };

  PianoPlayer.prototype.stop = function () {
    this.active.forEach(function (node) {
      try { node.stop(0); } catch (error) { /* already stopped */ }
    });
    this.active = [];
    this.duration = 0;
  };

  PianoPlayer.prototype.play = function (song) {
    var self = this;
    this.stop();
    var context = this.ensureContext();

    return this.loadVoice().then(function () {
      var notes = [];
      song.tracks.forEach(function (track) {
        var kit = track.channel === 9;
        track.notes.forEach(function (note) {
          notes.push({ note: note, kit: kit });
        });
      });
      var pitches = notes.filter(function (item) { return !item.kit; })
        .map(function (item) { return item.note.pitch; });
      return self.decode(pitches).then(function () {
        var secondsPerBeat = 60 / song.tempo;
        var at = context.currentTime + 0.12;
        self.startedAt = at;
        self.duration = song.lengthBeats * secondsPerBeat + 1.2;

        notes.forEach(function (item) {
          var note = item.note;
          var start = at + note.start * secondsPerBeat;
          var length = Math.max(0.06, note.duration * secondsPerBeat);
          var gainValue = Math.max(0.02, (note.velocity / 127) * 0.34);
          if (item.kit) {
            self.playDrum(note.pitch, start, gainValue);
          } else if (self.voice === 'soundfont') {
            self.playSample(note.pitch, start, length, gainValue);
          } else {
            self.playSynth(note.pitch, start, length, gainValue);
          }
        });
        return self.voice;
      });
    });
  };

  PianoPlayer.prototype.position = function () {
    if (!this.context || !this.duration) { return null; }
    var elapsed = this.context.currentTime - this.startedAt;
    if (elapsed < 0) { return 0; }
    if (elapsed > this.duration) { return null; }
    return elapsed;
  };

  global.PianoPlayer = PianoPlayer;
}(window));
