-- Synthetic rank readings: progress can be a quiet story without a cap,
-- inferred crafting, or a new control. No real player's history is used.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local P, Text, YD = ns.ProfessionCaps, ns.UI.JourneyText, ns.UI.YourDiary
local t0 = 1791000000
mock.now = t0 + 3600
mock.SetUnit("player", F.Like(F.SELF, { level = 10 }))

local function Gain(line, name, from, rank, t)
    return { skillLine = line, name = name, fromRank = from, rank = rank, max = 75,
        started = t - 60, t = t, level = 10, mapID = 1412, x = 0.4, y = 0.6 }
end
local ore = Gain(186, "Mining", 61, 69, t0 + 600)

Section("only the observed skill range is said")
Eq(P.ProgressWords(ore), "Mining from 61 to 69", "the short range")
Eq(P.ProgressSentence(ore), "Mining went from 61 to 69.", "a plain factual sentence")
local nameless = Gain(186, nil, 4, 7, t0 + 800)
Eq(P.ProgressSentence(nameless), "A profession went from 4 to 7.", "an absent name is not guessed")
for _, rec in ipairs({ {}, { fromRank = 10, rank = 20 }, Gain(186, "Mining", 8, 8, t0 + 800),
    Gain(186, "Mining", 9, 8, t0 + 800), Gain(186, "Mining", 8.5, 9, t0 + 800) }) do
    Eq(P.ProgressSentence(rec), nil, "an unsupported range says nothing")
end
local title, tip = P.ProgressTip(ore, mock.now)
Eq(title, "Mining from 61 to 69", "the tooltip keeps the range")
Check(#tip == 1 and tip[1]:find("level 10", 1, true), "the reading's time and level remain accessible")
Check(not tip[1]:find("minute", 1, true), "the reading interval is not called time spent practising")

Section("a short paragraph keeps different professions and time order")
local ore2 = Gain(186, "Mining", 69, 70, t0 + 700)
local aid = Gain(129, "First Aid", 20, 22, t0 + 900)
local fish = Gain(356, "Fishing", 31, 33, t0 + 1100)
local records = { fish, ore2, aid, ore, ore }
local chosen = P.ProgressSelected(records)
Eq(#chosen, 3, "the paragraph has three factual stretches")
Eq(chosen[1], ore, "the first Mining stretch comes first")
Eq(chosen[2], aid, "a different profession precedes repeated Mining")
Eq(chosen[3], fish, "the latest chosen fact is last")
Eq(records[1], fish, "selection does not sort the source table")
Eq(#records, 5, "selection leaves all source references intact")
Eq(P.ProgressLines({ skillProgress = records }),
    "Mining went from 61 to 69. First Aid went from 20 to 22. Fishing went from 31 to 33.",
    "the selected ranges are not fused across a gap")
Eq(P.ProgressLines({}), nil, "a quiet hour without a gain gets no invented progress")

Section("the existing stairs distinguish gains from reached caps")
local Plate = ns.UI.JourneyPlate
local boxes = {}
local kit = { ink = "ink", inner = "paper", INK_STRONG = {}, P = {},
    Clamp = function(n, lo, hi) return math.max(lo, math.min(n, hi)) end,
    Box = function(pool) boxes[pool] = (boxes[pool] or 0) + 1 end }
Plate.MARKS.skillProgress.draw(kit, 0, 0, 69)
Eq(boxes.paper, 4, "below75 every step remains uncompleted")
boxes = {}
Plate.MARKS.skill.draw(kit, 0, 0, 75)
Eq(boxes.paper, 3, "the reached-cap glyph retains its filled first step")
local moments = { { kind = "skillProgress", t = ore.t, progress = ore } }
Eq(Text.PlateCaption({ mapID = 1412, moments = moments }), "Mining from 61 to 69.",
    "progress can lead a quiet plate")

Section("a solo quiet sitting carries its gain on the page and mark")
ns.db.journey[F.SELF.guid] = nil
local j = ns.Journey.Begin(F.SELF.guid, t0, 10, 1412)
j.segments = { { kind = "stop", from = t0, to = t0 + 1800, seconds = 1800,
    mapID = 1412, x = 0.4, y = 0.6, r = 20, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 10 } }
j.skillProgress = { ore }
ns.Journey.Touch()
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
ns.UI.RefreshJourneyPage()
local page = ns.UI.JourneyPage()
YD.OpenLevel(1)
local plate = page.plates[1]
Check(plate:IsShown(), "the quiet progress has a plate")
Eq(plate.counts.skillProgress, 1, "its registered mark is drawn")
Eq(plate.counts.skills or 0, 0, "the gain is not a cap")
local words = {}
for _, item in ipairs(page.items) do if item.text then words[#words + 1] = item.text end end
Check(table.concat(words, " "):find("Mining went from 61 to 69.", 1, true), "the sitting tells its own gain")
local hover
for _, mk in ipairs(plate:Marks()) do
    if mk.frame.spot and mk.frame.spot.kind == "skillProgress" then hover = mk.frame end
end
Check(hover ~= nil, "the gain's mark keeps a tooltip target")
local lines = hover.tip()
Eq(lines[1][1], "Mining from 61 to 69", "the map retains the exact observed endpoints")

Section("the progress mark is reachable with the existing controller scope")
local Pad = ns.UI.Pad
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
YD.OpenLevel(1)
local catcher = Pad.Catcher(ns.UI.JournalFrame())
local function Press(key) mock.PadPress(catcher, key, true); mock.PadPress(catcher, key, false) end
local scope = Pad.Top()
local pageItem
for _, item in ipairs(scope.focus.groups.page.items) do if item.plate == 1 then pageItem = item end end
Check(pageItem ~= nil, "the plate is in the pad scope")
scope.focus:Set(pageItem)
Press("PAD1")
local progress
for _, item in ipairs(Pad.Top().focus.groups.marks.items) do
    if item.frame.spot and item.frame.spot.kind == "skillProgress" then progress = item end
end
Check(progress ~= nil, "the pad finds the new mark without another widget")
Pad.Top().focus:Set(progress)
Check(GameTooltip.shown, "focus shows the reading's tooltip")
Press("PAD2")
Eq(Pad.Top().focus:Current().group, "page", "B returns to the plate")
