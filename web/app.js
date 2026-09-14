/* The one screen: a prompt goes in, MIDI comes out. */
(function () {
  'use strict';

  var TRACK_COLOURS = { Melody: '#7bd4a8', Chords: '#6a8fd8', Bass: '#c98bd4' };
  var EXAMPLES = [
    'a sad lo-fi piano loop in F minor at 82 bpm',
    'epic cinematic build in 3/4, 32 bars',
    'a celtic jig',
    'dreamy ambient pad, sparse, 8 bars',
    'bebop jazz piano in Bb major',
    'slow blues in E'
  ];

  var form = document.getElementById('prompt-form');
  var promptInput = document.getElementById('prompt');
  var generateButton = document.getElementById('generate');
  var resultSection = document.getElementById('result');
  var summaryEl = document.getElementById('summary');
  var unmatchedEl = document.getElementById('unmatched');
  var chordsEl = document.getElementById('chords');
  var canvas = document.getElementById('roll');
  var playButton = document.getElementById('play');
  var againButton = document.getElementById('again');
  var downloadLink = document.getElementById('download');
  var seedEl = document.getElementById('seed');
  var statusEl = document.getElementById('status');
  var corpusNote = document.getElementById('corpus-note');
  var voiceNote = document.getElementById('voice-note');
  var examplesEl = document.getElementById('examples');

  var player = new window.PianoPlayer();
  var current = null;
  var frame = null;

  function setStatus(message, isError) {
    statusEl.textContent = message || '';
    statusEl.classList.toggle('error', Boolean(isError));
  }

  function base64ToBlob(base64) {
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) { bytes[i] = binary.charCodeAt(i); }
    return new Blob([bytes], { type: 'audio/midi' });
  }

  function drawRoll(song, position) {
    var context = canvas.getContext('2d');
    var width = canvas.width;
    var height = canvas.height;
    context.clearRect(0, 0, width, height);

    var notes = [];
    song.tracks.forEach(function (track) {
      track.notes.forEach(function (note) {
        notes.push({ note: note, colour: TRACK_COLOURS[track.name] || '#8a90a4' });
      });
    });
    if (!notes.length) { return; }

    var lowest = 127;
    var highest = 0;
    notes.forEach(function (item) {
      lowest = Math.min(lowest, item.note.pitch);
      highest = Math.max(highest, item.note.pitch);
    });
    lowest -= 2;
    highest += 2;

    var beats = Math.max(song.lengthBeats, 1);
    var rowHeight = height / (highest - lowest + 1);
    var beatWidth = width / beats;

    // Bar lines, so the phrasing is readable at a glance.
    var beatsPerBar = song.meter[0] * 4 / song.meter[1];
    context.strokeStyle = 'rgba(255,255,255,0.06)';
    context.lineWidth = 1;
    for (var beat = 0; beat <= beats; beat += beatsPerBar) {
      var x = beat * beatWidth;
      context.beginPath();
      context.moveTo(x, 0);
      context.lineTo(x, height);
      context.stroke();
    }

    // Section boundaries: where the form actually turns over.
    var sections = (current && current.sections) || [];
    if (sections.length > 1) {
      context.font = '11px ui-sans-serif, system-ui, sans-serif';
      sections.forEach(function (section, index) {
        var x = (section.startBar - 1) * beatsPerBar * beatWidth;
        if (index % 2 === 1) {
          context.fillStyle = 'rgba(255,255,255,0.025)';
          context.fillRect(x, 0, section.bars * beatsPerBar * beatWidth, height);
        }
        context.strokeStyle = 'rgba(255,255,255,0.18)';
        context.beginPath();
        context.moveTo(x, 0);
        context.lineTo(x, height);
        context.stroke();
        context.fillStyle = 'rgba(255,255,255,0.45)';
        context.fillText(section.label, x + 5, 14);
      });
    }

    notes.forEach(function (item) {
      var note = item.note;
      var x = note.start * beatWidth;
      var w = Math.max(2, note.duration * beatWidth - 1);
      var y = (highest - note.pitch) * rowHeight;
      var h = Math.max(2, rowHeight - 1);
      context.globalAlpha = 0.35 + (note.velocity / 127) * 0.65;
      context.fillStyle = item.colour;
      context.fillRect(x, y, w, h);
    });
    context.globalAlpha = 1;

    if (position !== null && position !== undefined) {
      var playhead = (position / (60 / song.tempo)) * beatWidth;
      context.strokeStyle = '#ffffff';
      context.lineWidth = 2;
      context.beginPath();
      context.moveTo(playhead, 0);
      context.lineTo(playhead, height);
      context.stroke();
    }
  }

  function highlightChord(beatPosition) {
    if (!current) { return; }
    var beatsPerBar = current.song.meter[0] * 4 / current.song.meter[1];
    var cycle = Number(chordsEl.dataset.cycle) || 1;
    var index = Math.floor(beatPosition / beatsPerBar) % cycle;
    Array.prototype.forEach.call(chordsEl.children, function (child) {
      child.classList.toggle('active', Number(child.dataset.cycleIndex) === index);
    });
  }

  function animate() {
    var position = player.position();
    if (position === null) {
      stopPlayback();
      return;
    }
    drawRoll(current.song, position);
    highlightChord(position / (60 / current.song.tempo));
    frame = requestAnimationFrame(animate);
  }

  function stopPlayback() {
    player.stop();
    if (frame) { cancelAnimationFrame(frame); frame = null; }
    playButton.textContent = 'Play';
    if (current) { drawRoll(current.song, null); }
    Array.prototype.forEach.call(chordsEl.children, function (child) {
      child.classList.remove('active');
    });
  }

  function startPlayback() {
    if (!current) { return; }
    playButton.disabled = true;
    player.play(current.song).then(function (voice) {
      playButton.disabled = false;
      playButton.textContent = 'Stop';
      voiceNote.textContent = voice === 'soundfont'
        ? ''
        : 'No piano soundfont reachable, so this is the built-in fallback tone. '
          + 'Run tools/fetch_soundfont.py to vendor one locally.';
      frame = requestAnimationFrame(animate);
    }).catch(function (error) {
      playButton.disabled = false;
      setStatus('Could not start audio: ' + error.message, true);
    });
  }

  /* A sixteen-bar piece over a four-chord progression is four chips and a
   * "x4", not sixteen chips: the repeat is the thing to show, not to spell. */
  function cycleLength(chords) {
    var symbols = chords.map(function (chord) { return chord.symbol; });
    // The cycle need not divide the piece: a six-chord progression over
    // sixteen bars still repeats every six, it just stops part way through.
    for (var length = 1; length <= Math.floor(symbols.length / 2); length += 1) {
      var repeats = true;
      for (var i = length; i < symbols.length && repeats; i += 1) {
        if (symbols[i] !== symbols[i % length]) { repeats = false; }
      }
      if (repeats) { return length; }
    }
    return symbols.length;
  }

  function renderChords(chords) {
    chordsEl.innerHTML = '';
    if (!chords.length) { return; }
    var length = cycleLength(chords);
    var shown = Math.min(length, 12);

    chords.slice(0, shown).forEach(function (chord, index) {
      var chip = document.createElement('span');
      chip.className = 'chord';
      chip.dataset.bar = chord.bar;
      chip.dataset.cycleIndex = index;
      chip.textContent = (chord.symbol || chord.roman) + ' ';
      var roman = document.createElement('span');
      roman.className = 'roman';
      // What the chord is doing - "V7/vi", "SubV7/V", "ii/IV" - rather than
      // the bare numeral, which says less.
      roman.textContent = chord.function || chord.roman;
      chip.appendChild(roman);
      chordsEl.appendChild(chip);
    });

    if (chords.length > shown) {
      var badge = document.createElement('span');
      badge.className = 'chord repeat';
      badge.textContent = shown < length
        ? '+' + (length - shown) + ' more'
        : 'repeats every ' + length + ' bars';
      chordsEl.appendChild(badge);
    }
    chordsEl.dataset.cycle = length;
  }

  function show(data) {
    current = data;
    resultSection.hidden = false;
    summaryEl.textContent = data.summary;

    var unmatched = data.spec.unmatched_terms || [];
    unmatchedEl.hidden = unmatched.length === 0;
    unmatchedEl.textContent = unmatched.length
      ? 'Not understood yet, so ignored: ' + unmatched.join(', ')
      : '';

    renderChords(data.chords);
    drawRoll(data.song, null);

    seedEl.textContent = data.spec.seed;
    downloadLink.href = URL.createObjectURL(base64ToBlob(data.midiBase64));
    downloadLink.download = data.filename;
    setStatus('');
  }

  function generate(options) {
    var prompt = promptInput.value.trim();
    stopPlayback();
    generateButton.disabled = true;
    setStatus('Composing...');

    var body = { prompt: prompt };
    if (options && options.seed) { body.seed = options.seed; }

    fetch('/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(function (response) {
      return response.json().then(function (data) {
        if (!response.ok) { throw new Error(data.error || 'request failed'); }
        return data;
      });
    }).then(function (data) {
      generateButton.disabled = false;
      show(data);
    }).catch(function (error) {
      generateButton.disabled = false;
      setStatus(error.message, true);
    });
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    generate();
  });

  playButton.addEventListener('click', function () {
    if (frame) { stopPlayback(); } else { startPlayback(); }
  });

  againButton.addEventListener('click', function () { generate(); });

  document.addEventListener('keydown', function (event) {
    if (event.code === 'Space' && document.activeElement !== promptInput && current) {
      event.preventDefault();
      if (frame) { stopPlayback(); } else { startPlayback(); }
    }
  });

  EXAMPLES.forEach(function (example, index) {
    if (index) { examplesEl.appendChild(document.createTextNode(' · ')); }
    var button = document.createElement('button');
    button.type = 'button';
    button.textContent = example;
    button.addEventListener('click', function () {
      promptInput.value = example;
      generate();
    });
    examplesEl.appendChild(button);
  });

  fetch('/api/vocabulary').then(function (r) { return r.json(); }).then(function (data) {
    var genres = Object.keys(data.genres || {}).length;
    var moods = Object.keys(data.moods || {}).length;
    var entries = (data.corpus && data.corpus.entries) || 0;
    corpusNote.textContent = genres + ' genres and ' + moods + ' moods understood · '
      + (entries ? entries + ' labelled corpus files in use'
                 : 'no corpus loaded yet, using built-in musical priors');
  }).catch(function () { /* the app works without this */ });
}());
