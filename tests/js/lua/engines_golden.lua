--[[ Every generator adapter, every setting, many seeds - printed.

     Run under the real Lua 5.4 this writes engines.expected; run under
     Middaw's Lua (tests/js/test_lua.js) it must print the same bytes. Numbers
     are printed with tostring, so a float that should be an integer (or the
     other way round) shows up too.

       lua5.4 tests/js/lua/engines_golden.lua family/engines/ > tests/js/lua/engines.expected
]]
local ROOT = arg and arg[1] or "family/engines/"
local cache = {}
function engine(name)
  if cache[name] == nil then
    local chunk = assert(loadfile(ROOT .. name))
    cache[name] = chunk() or false
  end
  return cache[name]
end

local function twinkle()
  return {
    { start = 0, len = 1, pitch = 60, vel = 100 }, { start = 1, len = 1, pitch = 60, vel = 100 },
    { start = 2, len = 1, pitch = 67, vel = 100 }, { start = 3, len = 1, pitch = 67, vel = 100 },
    { start = 4, len = 1, pitch = 69, vel = 100 }, { start = 5, len = 1, pitch = 69, vel = 100 },
    { start = 6, len = 2, pitch = 67, vel = 100 },
  }
end
local function chords()
  local n = {}
  local prog = { { 60, 64, 67 }, { 57, 60, 64 }, { 53, 57, 60 }, { 55, 59, 62 } }
  for b, ch in ipairs(prog) do
    for _, p in ipairs(ch) do n[#n + 1] = { start = (b - 1) * 4, len = 4, pitch = p, vel = 90 } end
  end
  return n
end

local CONTEXTS = {
  { name = "C major 4/4 viola, a tune", root = 1, scale = 1, num = 4, den = 4, barBeats = 4, bpm = 110,
    inst = "vla", catalogueId = "vla", bars = 4, selection = { beats = 8, drums = false, notes = twinkle() } },
  { name = "A minor 3/4 flute, chords", root = 10, scale = 2, num = 3, den = 4, barBeats = 3, bpm = 90,
    inst = "fl", catalogueId = "fl", bars = 8, selection = { beats = 16, drums = false, notes = chords() } },
  { name = "Eb dorian 6/8 piano", root = 4, scale = 6, num = 6, den = 8, barBeats = 3, bpm = 140,
    inst = "pno", catalogueId = "pno", bars = 2, selection = { beats = 8, drums = false, notes = twinkle() } },
}

local function out(...) io.write(table.concat({ ... }, " "), "\n") end

local function show(res, limit)
  if res.message then out("  message", res.message) end
  for i, r in ipairs(res.results or {}) do
    if i > limit then break end
    out("  *", tostring(r.title), "|", tostring(r.detail), "|", tostring(r.beats))
    for _, part in ipairs(r.parts or {}) do
      local cells = {}
      for _, n in ipairs(part.notes or {}) do
        cells[#cells + 1] = tostring(n.start) .. ":" .. tostring(n.len) .. ":" .. tostring(n.pitch) .. ":" .. tostring(n.vel)
      end
      out("   ", tostring(part.name), tostring(part.drums), (type(part.instrument) == "table" and tostring(part.instrument.id) or tostring(part.instrument)), table.concat(cells, " "))
    end
  end
end

for _, path in ipairs(engine("adapters/index.lua")) do
  local A = engine(path)
  for ci, ctx in ipairs(CONTEXTS) do
    local st = A.newState()
    A.useKey(st, ctx.root, ctx.scale)
    out("==", A.id, A.name, A.input, tostring(A.panel), "|", ctx.name)
    local settings = A.settings(st, ctx)
    for _, s in ipairs(settings) do
      out("  setting", s.id, s.label, "[" .. table.concat(s.names, ",") .. "]", tostring(s.index), s.group or "")
    end
    for seed = 1, (ci == 1 and 6 or 3) do
      local ok, res = pcall(A.generate, st, ctx, seed * 37, 3)
      out(" seed", seed * 37, tostring(ok))
      if ok then show(res, 3) else out("  error", tostring(res)) end
    end
    if ci == 1 then
      -- every value of every setting, one result each
      for _, s in ipairs(settings) do
        for i = 1, #s.names do
          local copy = A.newState()
          A.useKey(copy, ctx.root, ctx.scale)
          A.set(copy, s.id, i, ctx)
          local ok, res = pcall(A.generate, copy, ctx, 1000 + i, 1)
          out(" set", s.id, i, tostring(ok))
          if ok then show(res, 1) else out("  error", tostring(res)) end
        end
      end
    end
  end
end
