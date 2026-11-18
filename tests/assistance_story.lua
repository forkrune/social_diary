-- Synthetic attributable actions: help can earn its own place without a
-- manufactured death, close call, rescue or health reading.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local W, Text, YD = ns.Witnesses, ns.UI.JourneyText, ns.UI.YourDiary
local Card = W.Card
local t0 = 1791000000
mock.now = t0 + 3600
mock.SetUnit("player", F.Like(F.SELF, { level = 10 }))
local A, B, C, D = "Player-0000-A1000001", "Player-0000-A1000002", "Player-0000-A1000003", "Player-0000-A1000004"
for i, guid in ipairs({ A, B, C, D }) do
    ns.Characters.Observe(guid, { first = ({ "Mira", "Orik", "Sera", "Tovin" })[i], level = 10, faction = "Horde" })
end
local function Aid(guid, action, started, ended)
    local c = { evidence = 1, method = action == "kill" and "party_kill" or "meter", action = action,
        started = started, ended = ended, grouped = false, amount = 1 }
    c[action == "heal" and "healed" or action == "absorb" and "absorbed" or action == "dispel" and "dispelled" or "kills"] = 1
    local row = { type = W.AID, time = ended, me = F.SELF.guid, myLevel = 10, context = c,
        mapID = 1412, zone = "Mulgore", x = 0.4, y = 0.6 }
    return { t = ended, level = 10, mapID = 1412, x = 0.4, y = 0.6, guid = guid, row = row }
end
local heal = Aid(A, "heal", t0 + 300, t0 + 330)

Section("the card adapts actual help without inventing an outcome")
local w = Card.Assistance(heal, { 100, 100 })
Eq(W.Deed(w), "healed you", "the action's existing words are reused")
Eq(w.call, nil, "no artificial close call")
Eq(w.death, nil, "no artificial death")
Eq(w.pct, nil, "no health reading")
Eq(Card.Evidence(w), nil, "no health chart")
Eq(Card.Blood(w), nil, "no death decoration")
local _, tip = W.Tip(w, mock.now)
Check(table.concat(tip, " "):find("level 10", 1, true), "a standalone action retains the owner's level")
local unproved = Aid(A, "heal", t0 + 300, t0 + 330)
unproved.row.context.evidence = nil
Eq(Card.Assistance(unproved), nil, "legacy targeting is not promoted to help")
local malformed = Aid(A, "heal", t0 + 300, t0 + 330)
malformed.row.context.healed = 0
Eq(Card.Assistance(malformed), nil, "an evidence tag without a positive matching action cannot become a headline")
local grouped = Aid(A, "heal", t0 + 300, t0 + 330)
grouped.row.context.grouped = true
Eq(Card.Assistance(grouped), nil, "routine party healing is not a standalone card")
local wrongTime = Aid(A, "heal", t0 + 300, t0 + 330)
wrongTime.t = wrongTime.t + 1
Eq(Card.Assistance(wrongTime), nil, "a different endpoint cannot borrow proof")

Section("several actors in one encounter do not become several highlights")
local second = Aid(B, "heal", t0 + 300, t0 + 330)
local shield = Aid(C, "absorb", t0 + 500, t0 + 530)
local dispel = Aid(D, "dispel", t0 + 700, t0 + 730)
local later = Aid(A, "kill", t0 + 900, t0 + 930)
local records = { later, dispel, second, shield, heal, heal }
local selected = W.AssistanceSelected(records)
Eq(#selected, 3, "three accounts at most")
Eq(selected[1].t, heal.t, "selection is told chronologically")
Eq(selected[1].guid, A, "an exact tie has a stable subject")
Eq(selected[1].others, 1, "the same source row is not counted twice")
Eq(selected[2].t, shield.t, "a different encounter gets room")
Eq(selected[3].t, dispel.t, "the third encounter is last")
Eq(records[1], later, "the source order is not changed")
Eq(W.AssistanceLines({ assistance = records }),
    "Mira and another healed you. Sera shielded you. Tovin removed a harmful effect from you.",
    "the concise story says only attributed deeds")
local kill1, kill2 = Aid(A, "kill", t0 + 300, t0 + 330), Aid(B, "kill", t0 + 300, t0 + 330)
for _, chosen in ipairs(W.AssistanceSelected({ kill2, kill1 })) do
    Eq(chosen.others, 0, "different killing blows are not a shared kill")
end
Eq(W.AssistanceLines({}), nil, "no recorded help produces no help story")

Section("the ordinary witness slip works without death or close-call marks")
local marks = { { at = { 100, 100 }, list = { { kind = "assisted", assisted = second },
    { kind = "assisted", assisted = heal } } } }
local chosen = Card.Choose({}, {}, {}, function(x, y) return x, y end, marks)
Eq(chosen.guid, A, "the card's choice is deterministic")
Eq(chosen.others, 1, "the card names only a contributor to this action")
Eq(chosen.death, nil, "choosing aid creates no death")
Eq(chosen.call, nil, "choosing aid creates no close call")
local card = Card.New(CreateFrame("Frame", nil, UIParent))
for _, width in ipairs({ 142, 176 }) do
    card:SetWitness(chosen, "assistance-fixture", mock.now, A, function() end)
    card:Layout(10, 10, width)
    Check(not card.overfull, "the existing card fits at " .. width .. " px in the mock")
    Eq(card:Deed(), "healed you", "the card keeps its precise deed")
    Check(not card.figure:IsShown() and not card.barFill:IsShown(), "no automatic health chart leaks")
end
local plate = { mapID = 1412, moments = { { kind = "assisted", t = heal.t, assisted = heal } } }
Eq(Text.PlateCaption(plate), "Help in a fight.", "the help-only plate has a neutral lead")
Eq(Text.PlateCaption(plate, nil, { witness = w }), "Help in a fight. Mira healed you.",
    "the existing coda tells the action when the card cannot fit")

Section("captured help reaches the real sitting and its existing card pool")
ns.db.journey[F.SELF.guid] = nil
local j = ns.Journey.Begin(F.SELF.guid, t0, 10, 1412)
j.segments = { { kind = "stop", from = t0, to = t0 + 1800, seconds = 1800,
    mapID = 1412, x = 0.4, y = 0.6, r = 20, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 } }
ns.Interactions.Add(A, W.AID, { time = heal.t, session = false, context = heal.row.context,
    where = { zone = "Mulgore", mapID = 1412, x = 0.4, y = 0.6 } })
ns.Journey.Touch()
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
ns.UI.RefreshJourneyPage()
local page = ns.UI.JourneyPage()
YD.OpenLevel(1)
local p = page.plates[1]
Eq(p.counts.assistance, 1, "the standalone help ring is drawn")
Eq(p.counts.deaths or 0, 0, "the ring is not counted as a death")
Eq(p.counts.close or 0, 0, "the ring is not counted as a close call")
Check(p.witness and p.witness.assisted, "the existing witness pass chooses it")
Check(page.witnessPool.used > 0, "the existing witness card pool displays the action")
local body = {}
for _, item in ipairs(page.items) do if item.text then body[#body + 1] = item.text end end
Check(table.concat(body, " "):find("healed you", 1, true), "the sitting's prose includes the action")

Section("the assistance ring and card use existing controller discovery")
local Pad = ns.UI.Pad
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
YD.OpenLevel(1)
local catcher = Pad.Catcher(ns.UI.JournalFrame())
local function Press(key) mock.PadPress(catcher, key, true); mock.PadPress(catcher, key, false) end
local scope, plateItem, note = Pad.Top()
for _, item in ipairs(scope.focus.groups.page.items) do
    if item.plate == 1 then plateItem = item end
    if item.note and item.note.witness and item.note.witness.assisted then note = item end
end
Check(note ~= nil, "the precise action card is reachable")
scope.focus:Set(plateItem)
Press("PAD1")
local aidMark
for _, item in ipairs(Pad.Top().focus.groups.marks.items) do
    if item.frame.spot and item.frame.spot.kind == "assisted" then aidMark = item end
end
Check(aidMark ~= nil, "the assistance ring is reachable")
Pad.Top().focus:Set(aidMark)
Check(GameTooltip.shown, "the assistance tooltip opens under controller focus")
Press("PAD2")
Eq(Pad.Top().focus:Current().group, "page", "B returns from the ring to its plate")
