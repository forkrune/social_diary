-- An attributable intervention can stand on its own in Your Diary.
-- These synthetic rows exercise the derivation, not new combat evidence:
-- witness_detection and witness_evidence establish what capture may write.
local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local R, W = ns.JourneyRecap, ns.Witnesses
local ME, A, B = F.SELF.guid, F.STRANGER.guid, F.GARRICK.guid
local ALT, MAP = "Player-0000-AAAABBBB", 1412

local function Row(action, t)
    t = t or 150
    local row = { type = W.AID, me = ME, time = t, myLevel = 12,
        mapID = MAP, x = 0.4, y = 0.5,
        context = { evidence = 1, method = action == "kill" and "party_kill" or "meter", action = action,
            started = t - 20, ended = t, amount = (action == "kill" or action == "dispel") and 1 or 30 } }
    local counter = ({ heal = "healed", absorb = "absorbed", dispel = "dispelled", kill = "kills" })[action]
    row.context[counter] = row.context.amount
    return row
end

local function Setup(rows)
    local j = { startedAt = 100, startLevel = 12, levels = {}, segments = {}, marks = {} }
    local ctx = { me = ME, characters = { [A] = { first = "Bram" }, [B] = { first = "Garrick" } },
        interactions = rows or {}, now = 200, level = 12, diary = {} }
    return j, ctx
end

Section("each proven action can tell a survived fight without a close call")
for _, action in ipairs({ "heal", "absorb", "dispel", "kill" }) do
    local row = Row(action)
    local j, ctx = Setup({ [A] = { row } })
    local e = R.Gather(j, 100, 200, ctx)
    Eq(#e.assistance, 1, action .. " did not reach the owner's story")
    local rec = e.assistance[1]
    Eq(rec.row, row, "the derived record copied or rewrote source evidence")
    Eq(rec.guid, A, "the attributed helper")
    Eq(rec.t, 150, "the observed endpoint")
    Eq(rec.level, 12, "the owner's level")
    Eq(rec.mapID, MAP, "the observed place")
    local moments = R.Moments(j, e, ctx)
    Eq(#moments, 1, "a location-only aid became some other scenario")
    Eq(moments[1].kind, "assisted", "the assistance has its own kind")
    Eq(moments[1].assisted, rec, "the moment retains source context")
    local selection = R.Selection(moments[1])
    Eq(selection.family, "assistance", "the story family")
    Eq(selection.context, "linked", "the exact recipient action links the encounter")
    Eq(j.assistance, nil, "another player's identity was duplicated on the route")
    Eq(row.context.pct, nil, "derivation fabricated a health value")
end

Section("weak, stale, other-character and routine party evidence stays out")
local cases = {
    function(r) r.context.evidence = nil end,
    function(r) r.context.method = "target_streak" end,
    function(r) r.context.action = "witness" end,
    function(r) r.context.grouped = true end,
    function(r) r.context.started = nil end,
    function(r) r.context.started = r.time + 1 end,
    function(r) r.context.ended = r.time - 1 end,
    function(r) r.context.amount = 0; r.context.healed = 0 end,
    function(r) r.context.amount = -30; r.context.healed = -30 end,
    function(r) r.context.amount = math.huge; r.context.healed = math.huge end,
    function(r) r.context.amount = nil end,
    function(r) r.context.healed = nil end,
    function(r) r.context.healed = 29 end,
    function(r) r.context.kills = 1.5 end,
    function(r) r.me = ALT end,
    function(r) r.type = W.SAVED end,
    function(r) r.type = W.HELPED end,
    function(r) r.time = 99; r.context.ended = 99 end,
    function(r) r.time = 200; r.context.ended = 200 end,
}
for i, change in ipairs(cases) do
    local row = Row("heal")
    change(row)
    local j, ctx = Setup({ [A] = { row } })
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 0, "unqualified case " .. i .. " became a headline")
end
do
    local row = Row("heal", 100)
    local j, ctx = Setup({ [A] = { row } })
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 1, "the lower boundary is inclusive")
    j.startedAt = 101
    Eq(#R.Gather(j, 90, 200, ctx).assistance, 0, "pre-route help was backfilled")
    j.startedAt, ctx.me = 90, nil
    Eq(#R.Gather(j, 90, 200, ctx).assistance, 0, "unknown owner borrowed another character's history")
end

Section("an exact existing automatic close call carries the help once")
do
    local row = Row("heal")
    local j, ctx = Setup({ [A] = { row } })
    j.closeCalls = { { t = 150, pct = 8, mapID = MAP, x = 0.4, y = 0.5 } }
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 0, "the same help was told twice")
    j.closeCalls[1].t = 149
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 1, "a nearby second borrowed another encounter")
    j.closeCalls[1].t = 150
    j.closeCalls[1].custom = { hidden = true }
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 1, "a hidden card swallowed the observable action")
    j.closeCalls[1].custom = { name = "A handwritten account" }
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 1, "an edited card claimed the game's observation")
end

Section("one encounter is one event even when several people contribute")
do
    local a, b = Row("heal"), Row("absorb")
    local j, ctx = Setup({ [A] = { a, a }, [B] = { b } })
    local e = R.Gather(j, 100, 200, ctx)
    Eq(#e.assistance, 2, "duplicate rows inflated one actor's contribution")
    local moments = R.Moments(j, e, ctx)
    Eq(R.Selection(moments[1]).event, R.Selection(moments[2]).event,
        "multiple actors inflated the occurrence count")
    local later = Row("heal", 190)
    ctx.interactions[A][3] = later
    local again = R.Moments(j, R.Gather(j, 100, 200, ctx), ctx)
    Check(R.Selection(again[1]).event ~= R.Selection(again[3]).event, "a later encounter was erased")
    Eq(a.context.action, "heal", "one helper borrowed another action")
    Eq(b.context.action, "absorb", "one helper borrowed another action")

    -- Two positive source snapshots can arrive out of order. Select one
    -- whole observation, with capture's action order; never add its values
    -- to a replay, or let the append order pick what the person did.
    local healed, shielded = Row("heal"), Row("absorb")
    ctx.interactions, ctx.characters = { [A] = { shielded, healed } }, { [A] = { first = "Bram" } }
    Eq(R.Gather(j, 100, 200, ctx).assistance[1].row, healed, "canonical help followed append order")
    ctx.interactions[A] = { healed, shielded }
    Eq(R.Gather(j, 100, 200, ctx).assistance[1].row, healed, "replaying observations changed the deed")
    Eq(healed.context.healed, 30, "canonical selection summed replayed values")
end

Section("unknown places stay unknown and forgetting removes derived stories")
do
    local row = Row("dispel")
    row.mapID, row.x, row.y = nil, nil, nil
    local j, ctx = Setup({ [A] = { row } })
    local e = R.Gather(j, 100, 200, ctx)
    Eq(#e.assistance, 1, "an unplaced fact cannot reach prose")
    Eq(#R.Moments(j, e, ctx), 0, "an unplaced fact invented a map position")
    ctx.characters[A] = nil
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 0, "an orphan row revived a forgotten person")
    ctx.characters[A], ctx.interactions[A] = { first = "Bram" }, nil
    Eq(#R.Gather(j, 100, 200, ctx).assistance, 0, "a removed source row left a route copy")
end

Section("item discoveries and gifts worn use factual selection context")
do
    local find = { t = 150 }
    local selected = R.Selection({ kind = "find", t = 150, find = find })
    Eq(selected.context, "first", "first in recorded history is a supported distinction")
    Eq(selected.event, find, "the find stays one occurrence")
    local one = { t = 150, link = "item:54321", from = "loot" }
    local two = { t = 150, link = "item:54321", from = "loot" }
    Eq(R.Selection({ kind = "find", find = one }).event, R.Selection({ kind = "find", find = two }).event,
        "one item counted twice because it was both first shoulders and first green")
    two.link = "item:54322"
    Check(R.Selection({ kind = "find", find = one }).event ~= R.Selection({ kind = "find", find = two }).event,
        "different items acquired together were collapsed")
    two.link, two.customOf = one.link, {}
    Check(R.Selection({ kind = "find", find = one }).event ~= R.Selection({ kind = "find", find = two }).event,
        "an authored first was treated as an automatic duplicate")
    local upgrade = { t = 160, found = 150, from = "trade", guid = A }
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, "linked", "given then worn is linked")
    upgrade.guid = nil
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "unknown giver became a relationship")
    upgrade.guid, upgrade.found = A, 170
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "a future trade caused earlier wear")
    upgrade.found, upgrade.from = 150, "loot"
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "loot became a gift")
    upgrade.from, upgrade.guid = "trade", ""
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "an empty giver became a relationship")
    upgrade.guid, upgrade.found = A, -1
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "a malformed source time linked a gift")
    upgrade.found, upgrade.t = math.huge, math.huge
    Eq(R.Selection({ kind = "upgrade", upgrade = upgrade }).context, nil, "an unbounded source time linked a gift")
end
