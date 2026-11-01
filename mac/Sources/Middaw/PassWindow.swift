import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

/// DAW Battle Pass's own window: quests, the check-in calendar, loot, the
/// shop and stats. Everything here is bp_game.lua's, called unchanged; this
/// is only how it is shown.
struct PassWindow: View {
    @ObservedObject var pass = Pass.shared
    @State private var tab = "quests"

    var body: some View {
        let _ = pass.revision
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(pass.level)").heading()
                    ProgressView(value: pass.levelFraction).tint(Theme.accent).frame(width: 180)
                    Text("\(pass.xp) XP").foregroundStyle(Theme.textDim).font(.system(size: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tier \(pass.tier)").heading()
                    ProgressView(value: pass.tierFraction).tint(Theme.accent).frame(width: 140)
                    Text("\(Int(((1 - pass.tierFraction) * Pass.tierSeconds / 60).rounded(.up))) active minutes to the next")
                        .foregroundStyle(Theme.textDim).font(.system(size: 12))
                }
                Spacer()
                Text("\(pass.coins) coins").heading().monospacedDigit()
            }
            Choices(options: [("quests", "Quests"), ("checkin", "Check-In"), ("loot", "Loot"), ("shop", "Shop"), ("stats", "Stats")], selection: $tab)
            if !pass.lastResult.isEmpty {
                Text(pass.lastResult).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Theme.rule)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case "checkin": CheckInPage()
                    case "loot": LootPage()
                    case "shop": ShopPage()
                    case "stats": StatsPage()
                    default: QuestsPage()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 560)
        .background(Theme.ground)
        .onAppear { pass.start(); pass.read() }
    }
}

// --------------------------------------------------------------- reading --
func dict(_ x: Any?) -> [String: Any] { x as? [String: Any] ?? [:] }
func list(_ x: Any?) -> [[String: Any]] {
    if let l = x as? [[String: Any]] { return l }
    if let d = x as? [String: Any] { return d.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }.compactMap { d[$0] as? [String: Any] } }
    return []
}
func number(_ x: Any?) -> Double { (x as? NSNumber)?.doubleValue ?? 0 }
func text(_ x: Any?) -> String { x as? String ?? "" }

/// A rarity: its mark in the game's colour, and its name in words.
struct RarityMark: View {
    @ObservedObject var pass = Pass.shared
    let rarity: Int
    var body: some View {
        let r = pass.rarity(rarity)
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(r.color).frame(width: 4, height: 16).accessibilityHidden(true)
            Text(r.name).foregroundStyle(Theme.textDim).font(.system(size: 12))
        }
    }
}

/// A box on a page.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
    }
}

// ---------------------------------------------------------------- quests --
struct QuestsPage: View {
    @ObservedObject var pass = Pass.shared
    var body: some View {
        ForEach(["daily", "weekly"], id: \.self) { scope in
            let set = dict(pass.value(scope))
            Text(scope == "daily" ? "Today" : "This Week").heading()
            ForEach(Array(list(set["quests"]).enumerated()), id: \.offset) { i, q in QuestRow(scope: scope, index: i + 1, quest: q) }
        }
    }
}

struct QuestRow: View {
    @ObservedObject var pass = Pass.shared
    let scope: String
    let index: Int
    let quest: [String: Any]
    var body: some View {
        let target = max(1, number(quest["target"])), progress = number(quest["progress"])
        let timed = text(quest["kind"]) == "minutes" || text(quest["kind"]) == "session"
        let done = quest["done"] as? Bool ?? false, claimed = quest["claimed"] as? Bool ?? false
        Card {
            HStack {
                Text(text(quest["text"])).foregroundStyle(Theme.text)
                Spacer()
                RarityMark(rarity: Int(number(quest["rarity"])))
            }
            ProgressView(value: min(1, progress / target)).tint(Theme.accent)
            HStack(spacing: 8) {
                Text(timed ? "\(Int(progress / 60)) of \(Int(target / 60)) minutes" : "\(Int(progress)) of \(Int(target))")
                    .foregroundStyle(Theme.textDim).font(.system(size: 12)).monospacedDigit()
                Text(rewardText).foregroundStyle(Theme.textDim).font(.system(size: 12))
                Spacer()
                if claimed {
                    Text("Claimed").foregroundStyle(Theme.textDim).font(.system(size: 12))
                } else if done {
                    Button("Claim") { pass.act("claimQuest", [.s("$state"), .s("$session"), .s(scope), .n(Double(index))]) }.house(primary: true)
                } else {
                    Button("Reroll") { pass.act("reroll", [.s("$state"), .s("$session"), .s(scope), .n(Double(index))]) }
                        .house().disabled(!(pass.result("canReroll", [.s("$state"), .s(scope)]) as? Bool ?? false))
                        .help("Swap this quest for another")
                }
            }
        }
    }
    var rewardText: String {
        var s = "\(Int(number(quest["coins"]))) coins, \(Int(number(quest["xp"]))) XP"
        if let c = quest["crate"] as? NSNumber { s += ", a \(pass.rarity(c.intValue).name) crate" }
        return s
    }
}

// -------------------------------------------------------------- check-in --
struct CheckInPage: View {
    @ObservedObject var pass = Pass.shared
    var body: some View {
        let c = dict(pass.value("checkin"))
        let calendar = list(pass.constant("CHECKIN"))
        let available = pass.result("checkinAvailable", [.s("$state"), .n(Double(pass.epoch))]) as? Bool ?? false
        let today = Int(number(pass.result("checkinPreview", [.s("$state"), .n(Double(pass.epoch))])))
        Text("Streak \(Int(number(c["streak"]))) days, best \(Int(number(c["best"])))").heading()
        HStack(spacing: 6) {
            ForEach(Array(calendar.enumerated()), id: \.offset) { i, r in
                VStack(spacing: 4) {
                    Text("Day \(i + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(i + 1 == today ? Theme.ink : Theme.text)
                    Text(rewardText(r)).font(.system(size: 11)).foregroundStyle(i + 1 == today ? Theme.ink : Theme.textDim)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .padding(6).frame(width: 70, height: 76)
                .background(RoundedRectangle(cornerRadius: 6).fill(i + 1 == today ? Theme.accent : Theme.raised))
            }
        }
        Button(available ? "Check In" : "Checked In Today") {
            pass.act("checkin", [.s("$state"), .s("$session"), .n(Double(pass.epoch))])
        }
        .house(primary: available).disabled(!available)
    }
    func rewardText(_ r: [String: Any]) -> String {
        var parts: [String] = []
        if let c = r["coins"] as? NSNumber { parts.append("\(c.intValue) coins") }
        if let x = r["xp"] as? NSNumber { parts.append("\(x.intValue) XP") }
        if let t = r["token"] as? String { parts.append(t == "reroll" ? "a reroll" : t) }
        if let k = r["crate"] as? NSNumber { parts.append("\(pass.rarity(k.intValue).name) crate") }
        return parts.joined(separator: ", ")
    }
}

// ------------------------------------------------------------------ loot --
struct LootPage: View {
    @ObservedObject var pass = Pass.shared
    var body: some View {
        let inv = dict(pass.value("inv"))
        let crates = (inv["crates"] as? [NSNumber])?.map(\.intValue) ?? []
        let tokens = dict(inv["tokens"])
        Text("Crates").heading()
        if crates.allSatisfy({ $0 == 0 }) {
            Text("None yet: quests, check-ins and levels bring them.").foregroundStyle(Theme.textDim)
        }
        ForEach(Array(crates.enumerated()), id: \.offset) { i, n in
            if n > 0 {
                Card {
                    HStack {
                        RarityMark(rarity: i + 1)
                        Text("\(n) \(n == 1 ? "crate" : "crates")").foregroundStyle(Theme.text)
                        Spacer()
                        Button("Open") { pass.act("openCrate", [.s("$state"), .s("$session"), .n(Double(i + 1))]) }.house(primary: true)
                    }
                }
            }
        }
        Text("Tokens").heading()
        HStack(spacing: 12) {
            Text("Rerolls \(Int(number(tokens["reroll"])))").foregroundStyle(Theme.text)
            Text("Streak freezes \(Int(number(tokens["freeze"])))").foregroundStyle(Theme.text)
            Text("XP boosts \(Int(number(tokens["boost"])))").foregroundStyle(Theme.text)
            Spacer()
            Button("Use a Boost") { pass.act("useBoost", [.s("$state"), .s("$session")]) }.house().disabled(number(tokens["boost"]) < 1)
        }
        Text("Ideas").heading()
        let vault = list(pass.value("vault"))
        if vault.isEmpty { Text("Crates hold ideas: chords, beats, melodies to start from.").foregroundStyle(Theme.textDim) }
        ForEach(Array(vault.reversed().enumerated()), id: \.offset) { _, idea in
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text(idea["text"])).foregroundStyle(Theme.text)
                        Text("\(text(idea["name"])) - \(text(idea["sub"]))").foregroundStyle(Theme.textDim).font(.system(size: 12))
                    }
                    Spacer()
                    RarityMark(rarity: Int(number(idea["rarity"])))
                    Button("Use") { pass.useIdea(idea) }.house().help("Put it at the caret on the chosen track")
                }
            }
        }
        Text("Gear").heading()
        let gear = dict(pass.value("gear"))
        let equipped = dict(gear["equipped"])
        ForEach(equipped.keys.sorted(), id: \.self) { slot in
            let item = dict(equipped[slot])
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text(item["name"])).foregroundStyle(Theme.text)
                        Text("Worn - " + text(item["sub"])).foregroundStyle(Theme.textDim).font(.system(size: 12))
                    }
                    Spacer()
                    RarityMark(rarity: Int(number(item["rarity"])))
                    Button("Take Off") { pass.act("unequip", [.s("$state"), .s("$session"), .s(slot)]) }.house()
                }
            }
        }
        ForEach(Array(list(gear["stash"]).enumerated()), id: \.offset) { _, item in
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text(item["name"])).foregroundStyle(Theme.text)
                        Text(text(item["sub"])).foregroundStyle(Theme.textDim).font(.system(size: 12))
                    }
                    Spacer()
                    RarityMark(rarity: Int(number(item["rarity"])))
                    Button("Wear") { pass.act("equip", [.s("$state"), .s("$session"), .n(number(item["uid"]))]) }.house()
                    Button("Salvage") { pass.act("salvage", [.s("$state"), .s("$session"), .n(number(item["uid"]))]) }.house()
                        .help("Sell it for coins")
                }
            }
        }
    }
}

// ------------------------------------------------------------------ shop --
struct ShopPage: View {
    @ObservedObject var pass = Pass.shared
    var body: some View {
        let shop = dict(pass.value("shop"))
        let owned = dict(dict(pass.value("inv"))["passes"])
        Text("Today’s Deals").heading()
        ForEach(Array(list(shop["deals"]).enumerated()), id: \.offset) { i, deal in
            let drop = dict(deal["drop"]), price = Int(number(deal["price"]))
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text(drop["text"])).foregroundStyle(Theme.text)
                        Text("\(text(drop["name"])) - \(text(drop["sub"]))").foregroundStyle(Theme.textDim).font(.system(size: 12))
                    }
                    Spacer()
                    RarityMark(rarity: Int(number(drop["rarity"])))
                    if deal["bought"] as? Bool ?? false {
                        Text("Bought").foregroundStyle(Theme.textDim)
                    } else {
                        Button("\(price) coins") { pass.act("buyDeal", [.s("$state"), .s("$session"), .n(Double(i + 1))]) }
                            .house().disabled(pass.coins < price)
                    }
                }
            }
        }
        Text("Shop").heading()
        ForEach(Array(list(pass.constant("SHOP")).enumerated()), id: \.offset) { _, item in
            let id = text(item["id"]), price = Int(number(item["price"])), have = Int(number(owned[id]))
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text(item["name"])).foregroundStyle(Theme.text)
                        Text(text(item["desc"])).foregroundStyle(Theme.textDim).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if have > 0 {
                        Button("Redeem (\(have))") { pass.act("redeem", [.s("$state"), .s("$session"), .s(id), .n(Double(pass.epoch))]) }
                            .house(primary: true).help("Take the reward you bought")
                    }
                    Button("\(price) coins") { pass.act("buy", [.s("$state"), .s("$session"), .s(id)]) }.house().disabled(pass.coins < price)
                }
            }
        }
    }
}

// ----------------------------------------------------------------- stats --
struct StatsPage: View {
    @ObservedObject var pass = Pass.shared
    static let rows: [(String, String)] = [
        ("active", "Time making music"), ("longest", "Longest session"), ("sessions", "Sessions"), ("edits", "Edits"),
        ("tracks", "Tracks added"), ("notes", "Notes written"), ("takes", "Takes recorded"), ("ideasUsed", "Ideas used"),
        ("crates", "Crates opened"), ("dailies", "Daily quests done"), ("weeklies", "Weekly quests done"), ("tiers", "Tiers unlocked"),
        ("coinsEarned", "Coins earned"), ("coinsSpent", "Coins spent"), ("legendaries", "Legendary finds"), ("xpTotal", "XP earned"),
    ]
    var body: some View {
        let st = dict(pass.value("stats"))
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            ForEach(StatsPage.rows, id: \.0) { key, label in
                GridRow {
                    Text(label).foregroundStyle(Theme.label)
                    Text(key == "active" || key == "longest" ? hours(number(st[key])) : "\(Int(number(st[key])))")
                        .foregroundStyle(Theme.text).monospacedDigit()
                }
            }
        }
    }
    func hours(_ secs: Double) -> String {
        let m = Int(secs / 60)
        return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }
}

// ------------------------------------------------------- the game's side --
extension Pass {
    func value(_ path: String) -> Any? {
        guard let e = Studio.shared.engines, started else { return nil }
        return try? e.callAny("passGet", ["path": path])
    }
    func result(_ fn: String, _ args: [Arg]) -> Any? {
        guard let e = Studio.shared.engines, started else { return nil }
        return try? e.callAny("passCall", CallArgs(fn: fn, args: args))
    }
    func constant(_ name: String, loot: Bool = false) -> Any? {
        if let c = constants[name + (loot ? "@loot" : "")] { return c }
        guard let e = Studio.shared.engines else { return nil }
        let v = try? e.callAny("passConst", ["name": name, "module": loot ? "loot" : "game"])
        if let v { constants[name + (loot ? "@loot" : "")] = v }
        return v
    }
    func rarity(_ r: Int) -> (name: String, color: Color) {
        let l = list(constant("RARITY", loot: true))
        guard r >= 1, r <= l.count else { return ("", Theme.edge) }
        let col = UInt32(truncatingIfNeeded: Int64(number(l[r - 1]["col"])))
        return (text(l[r - 1]["name"]), Theme.hex(col >> 8))
    }
    var levelFraction: Double {
        let need = number(result("levelNeed", [.n(Double(level))]))
        return need > 0 ? min(1, Double(xp) / need) : 0
    }

    /// One of the game's actions, and what it gave said in words.
    func act(_ fn: String, _ args: [Arg]) {
        let r = result(fn, args)
        dirty = true
        read()
        let notices = drain()
        lastResult = Pass.say(fn, r, notices)
        save()
    }

    static func say(_ fn: String, _ r: Any?, _ notices: [[String: Any]]) -> String {
        switch fn {
        case "openCrate":
            let drops = list(r).map { text($0["text"]) }.filter { !$0.isEmpty }
            return drops.isEmpty ? "" : "In the crate: " + drops.joined(separator: ", ") + "."
        case "salvage": return "Salvaged for \(Int(number(r))) coins."
        case "checkin":
            let got = dict(r)
            var parts: [String] = []
            if let c = got["coins"] as? NSNumber { parts.append("\(c.intValue) coins") }
            if let x = got["xp"] as? NSNumber { parts.append("\(x.intValue) XP") }
            if got["token"] != nil { parts.append("a token") }
            if got["crate"] != nil { parts.append("a crate") }
            return "Day \(Int(number(got["day"]))) of the streak: " + parts.joined(separator: ", ") + "."
        default:
            if let n = notices.last, let t = n["text"] as? String ?? n["name"] as? String { return t }
            return (r as? Bool) == false ? "Not now." : ""
        }
    }

    /// An idea from the vault at the caret: chords and melodies as notes, a
    /// beat as the kit's notes.
    func useIdea(_ idea: [String: Any]) {
        guard let s = Studio.shared.active else { return }
        let data = dict(idea["data"])
        var notes: [Note] = [], beats = 4.0
        let name = text(idea["text"])
        if let block = data["block"] as? [String: Any] {
            beats = number(block["beats"])
            for n in list(block["notes"]) {
                notes.append(Note(start: number(n["start"]), len: number(n["len"]), pitch: Int(number(n["pitch"])), vel: Int(number(n["vel"]))))
            }
        } else if let d = data["drums"] as? [String: Any] {
            let steps = max(1, Int(number(d["steps"]))), bars = max(1, number(d["bars"]))
            beats = bars * s.project.beatsPerBar
            let step = beats / Double(steps)
            for row in list(d["rows"]) {
                let pitch = Int(number(row["note"]))
                for (i, v) in ((row["steps"] as? [NSNumber]) ?? []).enumerated() where v.intValue > 0 {
                    notes.append(Note(start: Double(i) * step, len: step * 0.9, pitch: pitch, vel: v.intValue))
                }
            }
        }
        guard !notes.isEmpty else { lastResult = "\(name): an idea to try by ear."; return }
        s.insertBlock(notes, beats: max(beats, 0.25), name: name)
        act("ideaUsed", [.s("$state"), .s("$session"), .n(number(idea["uid"]))])
        lastResult = "Put “\(name)” at the caret."
    }
}
