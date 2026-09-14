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
        track.notes.forEach(function (note) { notes.push(note); });
      });
      var pitches = notes.map(function (note) { return note.pitch; });
      return self.decode(pitches).then(function () {
        var secondsPerBeat = 60 / song.tempo;
        var at = context.currentTime + 0.12;
        self.startedAt = at;
        self.duration = song.lengthBeats * secondsPerBeat + 1.2;

        notes.forEach(function (note) {
          var start = at + note.start * secondsPerBeat;
          var length = Math.max(0.06, note.duration * secondsPerBeat);
          var gainValue = Math.max(0.02, (note.velocity / 127) * 0.34);
          if (self.voice === 'soundfont') {
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
