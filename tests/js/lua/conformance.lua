-- Integers beyond 2^53 and table addresses are left out: Middaw's
-- integers are JS doubles, exact to 2^53, and addresses are its own.
-- What Middaw's Lua must print exactly as the real Lua 5.4 does.
-- tests/js/lua/conformance.expected is this file's output under lua5.4.

print("-- numbers")
print(1, 1.0, -0.0, 3/2, 4/2, 7//2, 7.0//2, -7//2, 7%3, -7%3, 7%-3, -7.5%2, 2^10, 10//0.0)
print(1e15, 1e16, 123456789012, 0.1, 1/3, -1/3, 100/3, 2^53, 2^63, math.huge, -math.huge)
print(math.type(1), math.type(1.0), math.type("1"), math.floor(3.7), math.ceil(3.2), math.floor(-3.5))
print(math.max(1, 2.0, 3), math.min(4, 2.5), math.abs(-3), math.abs(-3.0), math.fmod(-7, 3), math.fmod(7, -3.5))
print(tostring(1e100), 5 // 0.0, -5 // 0.0, 3 | 5, 6 & 3, 5 ~ 3, ~0, 1 << 4, 256 >> 4, 1 << 62, -1 >> 60)
print(tonumber("10"), tonumber("10.0"), tonumber(" 0x1F "), tonumber("1e2"), tonumber("abc"), tonumber("ff", 16), tonumber("z", 36), tonumber(""))
print(10 == 10.0, "10" == 10, 1 < 2, "a" < "b", "Z" < "a", math.tointeger(3.0), math.tointeger(3.5))
print("10" + 5, "3.5" * 2, 10 .. 20, 1.5 .. "", -(-3), - "2")
for i = 1, 3 do io.write(i, " ") end
for i = 3, 1, -1 do io.write(i, " ") end
for x = 0, 1, 0.25 do io.write(x, " ") end
for i = 1, 2.9 do io.write(i, ";") end
print()

print("-- strings")
print(string.format("%d %5d %-5d| %05d %+d %x %X %o %c", 42, 42, 42, 42, 42, 255, 255, 8, 65))
print(string.format("%.2f %.0f %.0f %.0f %10.3f %-8.1f| %e %.3e %g %g %g %g", 3.14159, 2.5, 3.5, 0.5, -1.5, 2.25, 12345.678, 0.000123, 100000, 1e6, 0.0001, 1e-5))
print(string.format("%.1f %.2f %.3f %5.2f%%", 0.25, 1.005, 2.0005, 99.995))
print(string.format("%s %s %s %10s|%-10s|%.3s", nil, true, 1.0, "right", "left", "truncate"))
print(string.format("%q", 'a "quoted"\n\tstring\0end'), string.format("%g %g", 2^63, -0.0))
print(("x"):rep(3), ("ab"):rep(3, ","), ("Hello"):upper(), ("Hello"):lower(), #"héllo", ("abc"):reverse())
print(("hello world"):sub(1, 5), ("hello"):sub(-3), ("hello"):sub(2), ("hello"):sub(0), ("hello"):sub(10), ("hello"):byte(1, 3))
print(string.char(72, 105), ("%d"):format(7), ("a,b,,c"):find(",", 1, true), ("a.b"):find("."), ("a.b"):find(".", 1, true))
print(("hello world"):find("o w"), ("hello"):find("l+"), ("hello"):match("(h)(e)"), ("key = value"):match("^(%w+)%s*=%s*(%w+)$"))
print(("  trim me  "):match("^%s*(.-)%s*$"), ("2024-10-30"):match("(%d+)-(%d+)-(%d+)"), ("abc"):match("()b()"))
print(("hello world from lua"):gsub("o", "0"), ("hello"):gsub("", "-"), ("abc"):gsub("%w", "%0%0"), ("hello world"):gsub("(%w+)", "<%1>"))
print(("$name is $age"):gsub("%$(%w+)", {name = "Ann", age = 30}), ("abc"):gsub(".", function(c) return c:byte() end), ("x y z"):gsub("%s", "_", 1))
print(("f(a(b)c)d"):match("%b()"), ("THE (quick) fox"):find("%f[%a]%a+"), ("[test]"):match("%[(.-)%]"), ("a1b2c3"):gsub("%d", ""))
for w in ("one two  three"):gmatch("%a+") do io.write(w, "|") end
for k, v in ("a=1, b=2, c=3"):gmatch("(%w+)=(%w+)") do io.write(k, v, ";") end
for w in (""):gmatch(".*") do io.write("[", w, "]") end
print()
print(("C# Major"):match("^(%S+)%s+(.+)$"), ("%d%%"):format(50), ("a+b"):gsub("%+", " plus "), ("é"):byte(1, -1))

print("-- tables")
local t = {10, 20, 30, nil, 50}
print(#t, select("#", 1, nil, 3), select(2, "a", "b", "c"), select(-1, "a", "b", "c"))
local u = {}
for i = 1, 10 do u[i] = i * i end
table.remove(u, 1); table.insert(u, 1, 0); table.insert(u, 99); print(#u, table.concat(u, ","))
print(table.remove(u), table.remove(u, 1), #u, table.concat(u, "-", 2, 4), table.concat({1, 2.5, "x"}))
local words = {"pear", "apple", "fig", "banana", "kiwi", "date", "cherry", "grape", "lime", "melon", "plum", "peach"}
table.sort(words); print(table.concat(words, " "))
table.sort(words, function(a, b) return #a < #b end); print(table.concat(words, " "))
local nums = {}
for i = 1, 300 do nums[i] = (i * 7919) % 101 end
table.sort(nums, function(a, b) return a % 10 < b % 10 end)
local acc = {}
for i = 1, 300, 7 do acc[#acc + 1] = nums[i] end
print(table.concat(acc, ","))
local recs = {}
for i = 1, 40 do recs[i] = {k = i % 5, id = i} end
table.sort(recs, function(a, b) return a.k > b.k end)
local ids = {}
for i, r in ipairs(recs) do ids[i] = r.id end
print(table.concat(ids, " "))
print(table.unpack({1, 2, 3})); print(table.unpack({1, 2, 3}, 2)); print(select("#", table.unpack({}, 1, 3)))
local p = table.pack(1, nil, 3); print(p.n, p[1], p[2], p[3])
local keys = {}
local h = {x = 1, y = 2, z = 3, [1] = "a", [2] = "b"}
for k in pairs(h) do keys[#keys + 1] = tostring(k) end
table.sort(keys); print(table.concat(keys, ","))
print(next({}), type(next({5})), rawlen({1, 2}), rawequal(t, t), rawget(h, "x"))
local m = table.move({1, 2, 3, 4, 5}, 2, 4, 1); print(table.concat(m, ","))

print("-- functions")
local function va(...)
  local n = select("#", ...)
  local a, b = ...
  return n, a, b, #{...}
end
print(va()); print(va(1)); print(va(1, 2, 3))
local function multi() return 1, 2, 3 end
print(multi(), multi()); print((multi())); print(({multi(), multi()})[4], #{multi(), multi()})
local x, y, z = multi(); print(x, y, z)
local q, r = 1; print(q, r)
local counters = {}
for i = 1, 3 do counters[i] = function() return i end end
print(counters[1](), counters[2](), counters[3]())
local function fib(n) if n < 2 then return n end return fib(n - 1) + fib(n - 2) end
print(fib(20))
local obj = {n = 0}
function obj:inc(by) self.n = self.n + (by or 1); return self end
obj:inc():inc(5); print(obj.n)
local i = 0
repeat local j = i; i = i + 1 until j >= 3
print(i)
local a1, b1 = 1, 2; a1, b1 = b1, a1; print(a1, b1)
print(pcall(function() error("boom") end))
print(pcall(function() error("plain", 0) end))
print(select(2, pcall(function() error({code = 7}) end)).code)
print(select(2, pcall(function() local z = nil; return z.field end)) ~= nil)
print(pcall(error))
print(type(print), type(nil), type({}), type("s"), type(2), type(true))
print(string.format("%5.1f|%-6s|%3d", 7.25, "ab", 5))
local s = 0
for k, v in ipairs({1, 2, nil, 4}) do s = s + v end
print(s)
print(8 // 3 * 3 + 8 % 3, 2 ^ 3 ^ 2, -2 ^ 2, not nil == true, 1 .. 2 == "12")
print(#"abc" + 1, -#"ab", ("x"):len())

print("-- random")
math.randomseed(42)
local rs = {}
for k = 1, 8 do rs[k] = math.random(1, 100) end
print(table.concat(rs, " "))
math.randomseed(7)
print(math.random(10), math.random(3, 4), math.random(1000000), string.format("%.10f", math.random()))
math.randomseed(12345, 678)
print(math.random(1, 1000), math.random(1, 6))
local deck = {1, 2, 3, 4, 5, 6, 7, 8}
math.randomseed(99)
for k = #deck, 2, -1 do local j = math.random(k); deck[k], deck[j] = deck[j], deck[k] end
print(table.concat(deck, ","))

print("-- park-miller")
local seed = 4182
local st = math.floor(math.abs(seed)) % 2147483646 + 1
local out = {}
for k = 1, 5 do st = st * 48271 % 2147483647; out[k] = st end
print(table.concat(out, " "), (st - 1) / 2147483646)

print("-- utf8")
print(utf8.char(72, 233, 8364), utf8.len("héllo"), utf8.codepoint("é"))
print(os.time({year = 2026, month = 1, day = 1, hour = 0}) > 0, os.date("%Y", 0) ~= nil)
