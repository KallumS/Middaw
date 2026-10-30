/* The DAW's project model: placing music, editing it, and undo. */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const M = require('../../web/app/model.js').model;

function project() {
  const p = M.newProject();
  p.tracks.push(M.newTrack({ name: 'Piano', instrument: 'pno' }));
  return p;
}
const C_MAJOR = { root: 1, scale: 1 };

test('notes from the Python side and from MIDI files are taken as DAW notes', () => {
  const p = project(), t = p.tracks[0];
  const c = M.placeNotes(p, t.id, 0, 4, [{ start: 0, duration: 1, pitch: 60, velocity: 90 }, { start: 1, len: 0.5, pitch: 62, vel: 70 }]);
  assert.deepStrictEqual(c.notes, [{ start: 0, len: 1, pitch: 60, vel: 90 }, { start: 1, len: 0.5, pitch: 62, vel: 70 }]);
});

test('placing music clears what was under it, keeping both sides', () => {
  const p = project(), t = p.tracks[0];
  M.placeNotes(p, t.id, 0, 16, [0, 4, 8, 12].map((s) => ({ start: s, len: 2, pitch: 60, vel: 100 })));
  M.placeNotes(p, t.id, 4, 4, [{ start: 0, len: 1, pitch: 72, vel: 100 }]);
  assert.deepStrictEqual(t.clips.map((c) => [c.start, c.length]), [[0, 4], [4, 4], [8, 8]]);
  assert.deepStrictEqual(M.trackNotes(t).map((n) => [n.start, n.pitch]), [[0, 60], [4, 72], [8, 60], [12, 60]]);
});

test('a note is cut at the end of its clip', () => {
  const p = project(), t = p.tracks[0];
  const c = M.placeNotes(p, t.id, 0, 4, [{ start: 3, len: 4, pitch: 60, vel: 100 }, { start: 5, len: 1, pitch: 62, vel: 100 }]);
  assert.deepStrictEqual(c.notes.map((n) => [n.start, n.len]), [[3, 1]]);
});

test('turning a tune upside down keeps it in its key', () => {
  const notes = [60, 62, 64, 65, 67, 71].map((pitch, i) => ({ start: i, len: 1, pitch, vel: 100 }));
  M.invert(notes, C_MAJOR);
  const info = M.keyInfo(C_MAJOR);
  assert.ok(notes.every((n) => info.pcs[n.pitch % 12]), notes.map((n) => n.pitch).join(' '));
  assert.strictEqual(notes[0].pitch, 71);      // the lowest becomes the highest
  assert.strictEqual(notes[5].pitch, 60);
  assert.deepStrictEqual(notes.map((n) => n.pitch), [71, 69, 67, 65, 64, 60]);
});

test('a chromatic line is mirrored chromatically', () => {
  const notes = [60, 61, 63].map((pitch, i) => ({ start: i, len: 1, pitch, vel: 100 }));
  M.invert(notes, C_MAJOR);
  assert.deepStrictEqual(notes.map((n) => n.pitch), [63, 62, 60]);
});

test('played backwards, the rhythm is mirrored too', () => {
  const notes = [{ start: 0, len: 1, pitch: 60, vel: 1 }, { start: 1, len: 3, pitch: 62, vel: 1 }];
  M.retrograde(notes, 4);
  assert.deepStrictEqual(notes.map((n) => [n.start, n.pitch]), [[0, 62], [3, 60]]);
});

test('fitting to the key moves only the notes outside it', () => {
  const notes = [61, 62, 66, 70].map((pitch) => ({ start: 0, len: 1, pitch, vel: 1 }));
  M.fitToKey(notes, C_MAJOR);
  assert.ok(notes.every((n) => M.keyInfo(C_MAJOR).pcs[n.pitch % 12]));
  assert.strictEqual(notes[1].pitch, 62);
});

test('snapping and quantizing work bar by bar in odd meters', () => {
  const p = project(); p.meter = [7, 8];           // 3.5 beats a bar
  assert.strictEqual(M.beatsPerBar(p), 3.5);
  assert.strictEqual(M.snap(p, 3.6, 1), 3.5);       // the downbeat of bar 2, not beat 4
  const notes = [{ start: 4.6, len: 1, pitch: 60, vel: 1 }];
  M.quantize(p, notes, 1, 1);
  assert.strictEqual(notes[0].start, 4.5);
});

test('splitting a clip at a beat divides its notes', () => {
  const p = project(), t = p.tracks[0];
  const c = M.placeNotes(p, t.id, 0, 8, [{ start: 1, len: 1, pitch: 60, vel: 1 }, { start: 5, len: 1, pitch: 64, vel: 1 }]);
  const right = M.splitClip(t, c, 4);
  assert.deepStrictEqual([c.length, right.start, right.length], [4, 4, 4]);
  assert.deepStrictEqual(right.notes.map((n) => [n.start, n.pitch]), [[1, 64]]);
});

test('undo and redo walk the history and name each step', () => {
  const h = new M.History(project());
  const id = h.project.tracks[0].id;
  h.commit('Rename Track', (q) => { M.track(q, id).name = 'Lead'; });
  h.commit('Change Tempo', (q) => { q.tempo = 90; });
  assert.strictEqual(h.undoLabel(), 'Change Tempo');
  assert.strictEqual(h.undo(), 'Change Tempo');
  assert.strictEqual(h.project.tempo, 110);
  assert.strictEqual(h.project.tracks[0].name, 'Lead');
  assert.strictEqual(h.redo(), 'Change Tempo');
  assert.strictEqual(h.project.tempo, 90);
  h.undo(); h.commit('Mute', (q) => { q.tracks[0].mute = true; });
  assert.strictEqual(h.redoLabel(), null);        // a new step forgets the undone one
});

test('a commit that declines changes nothing and is not an undo step', () => {
  const h = new M.History(project());
  const before = h.project;
  assert.strictEqual(h.commit('Nothing', () => false), null);
  assert.strictEqual(h.project, before);
  assert.strictEqual(h.undoLabel(), null);
});
