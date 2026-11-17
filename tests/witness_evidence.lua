-- Unrelated snapshots no longer create a story. Old rows cannot acquire
-- stronger evidence retroactively, and explicit player interpretations
-- remain the player's words. New action detections live in witness_detection.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local W, Card = ns.Witnesses, ns.Witnesses.Card
local SELF, STRANGER = F.SELF, F.STRANGER
local STRIDER = "Creature-0-4615-1-832-2955-00004B69A3"
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"

local fighting = {}
_G.UnitAffectingCombat = function(unit)
    if unit == "player" then return mock.inCombat end
    local def = mock.units[unit]
    return def ~= nil and fighting[def.guid] == true
end
_G.GetTime = function() return mock.now end

local function Mob(guid, name)
    return { guid = guid, name = { name }, isPlayer = false, hostile = true }
end

mock.now = 1792000000
mock.zone = "Mulgore"
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()

local function Fresh()
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    T.BlankDiary()
    mock.ClearUnits()
    mock.SetUnit("player", SELF)
    fighting = {}
    mock.now = mock.now + 60
end

local function Chosen(row, guid, death)
    local index = { { t = row.time, guid = guid, row = row } }
    local crosses, marks = {}, {}
    if row.type == W.SAVED then
        marks[1] = { at = { 100, 100 }, list = { { call = { t = row.time, pct = 6 } } } }
    else
        crosses[1] = { x = 100, y = 100, deaths = { death or { t = row.time } } }
    end
    return Card.Choose(crosses, marks, index, function(x, y) return x, y end)
end

local function Automatic(row, guid)
    local w = Chosen(row, guid)
    Check(w ~= nil, "the observed encounter remains readable")
    local _, timeline = ns.UI.DescribeItem({ kind = "row", row = row }, guid)
    local _, tip = W.Tip(w, mock.now)
    local deed, underline = W.Deed(w)
    local all = table.concat({ timeline, deed, W.Deed(w, "many"), W.Deed(w, "line"),
        W.Caption(w), table.concat(tip, "|"), ns.Rows.Reason(row) }, "|")
    for _, unsupported in ipairs({ "merciless", "save", "rescu", "tried", "watched", "saw you",
        "joined", "refused", "help", "health", "%" }) do
        Check(not all:lower():find(unsupported, 1, true), "automatic wording claimed " .. unsupported .. ": " .. all)
    end
    Check(all:find("Bram", 1, true), "the observed person's identity remains")
    Check(table.concat(tip, "|"):find("Had you or a foe targeted", 1, true), "the tooltip states the available evidence")
    Eq(deed, row.type == W.SAVED and "was seen during the fight" or "was seen around the time you died",
        "the automatic deed states observation and outcome")
    Eq(W.Foe(w), nil, "a targeted creature is not an attributed killer or rescue")
    Eq(underline, nil, "no moral judgement is underlined")
    Eq(W.Look(w), nil, "target duration does not become a grade of attention")
    Eq(Card.Blood(w), nil, "automatic attention receives no escalating blood treatment")
    Eq(Card.Evidence(w), nil, "the automatic witness has no inferred health chart")
    return w, timeline
end

--------------------------------------------------------------------------
Section("targeting and unrelated combat do not become rescue or attempted rescue")

for _, survived in ipairs({ false, true }) do
    Fresh()
    local started = mock.now
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    mock.SetUnit("target", Mob(STRIDER, "Plainstrider"))
    mock.SetUnit("targettarget", SELF)
    mock.fire("PLAYER_TARGET_CHANGED")

    -- The stranger targets the player's foe while out of combat.
    mock.SetUnit("nameplate1", STRANGER)
    mock.SetUnit("nameplate1target", Mob(STRIDER, "Plainstrider"))
    mock.fire("UNIT_TARGET", "nameplate1")
    -- Later they enter combat with a different creature. Capture notes
    -- targeting and combat independently; neither proves a helpful act.
    mock.now = mock.now + 1
    fighting[STRANGER.guid] = true
    mock.SetUnit("nameplate1target", Mob(WOLF, "Timber Wolf"))
    ns._test.WitnessesScan()
    mock.now = mock.now + 10

    if survived then
        mock.inCombat = false
        mock.fire("PLAYER_REGEN_ENABLED")
        ns.Fire("SD_FIGHT_SURVIVED", started, mock.now, 94, 100, { npcID = 2955, name = "Plainstrider" })
    else
        mock.fire("PLAYER_DEAD")
    end
    for _, kind in ipairs({ W.WATCHED, W.HELPED, W.SAVED, W.AID }) do
        Eq(ns._test.LatestInteraction(STRANGER.guid, kind), nil,
            "unrelated targeting and combat produced " .. kind)
    end
end

--------------------------------------------------------------------------
Section("a first sample at death does not claim an earlier observation")

Fresh()
-- An out-of-combat death, such as a fall. No targeting event was sampled
-- beforehand: the death handler itself makes the first observation.
mock.SetUnit("target", STRANGER)
mock.SetUnit("targettarget", SELF)
Eq(T.Rows(STRANGER.guid, W.WATCHED), 0, "no earlier witness observation exists")
mock.fire("PLAYER_DEAD")
Eq(ns._test.LatestInteraction(STRANGER.guid, W.WATCHED), nil,
    "the first observation at death must not invent earlier witnessing")

--------------------------------------------------------------------------
Section("old witness rows remain neutral without rewriting saved facts")

local contexts = { {}, { watched = 0 }, { watched = 1.5 }, { watched = 5 }, { watched = 30 } }
for _, context in ipairs(contexts) do
    local row = { type = W.WATCHED, time = mock.now, me = SELF.guid, zone = "Mulgore", context = context }
    local watched = context.watched
    Automatic(row, STRANGER.guid)
    Eq(row.context, context, "reading does not replace the saved context")
    Eq(context.watched, watched, "reading does not rewrite the observed duration")
end
for _, kind in ipairs({ W.WATCHED, W.HELPED, W.SAVED }) do
    Automatic({ type = kind, time = mock.now, me = SELF.guid }, STRANGER.guid)
    local context = { name = "Hogger", npcID = 448, rank = "rare", watched = 30, pct = 6 }
    local row = { type = kind, time = mock.now, me = SELF.guid, context = context }
    Automatic(row, STRANGER.guid)
    Eq(row.type, kind, "the persisted kind remains compatible")
    Eq(context.name, "Hogger", "the saved creature is not silently migrated")
    Eq(context.pct, 6, "the old estimate is retained without being presented as evidence")
end

--------------------------------------------------------------------------
Section("a death caption uses death evidence rather than the witness's target")

local row = { type = W.HELPED, time = mock.now, me = SELF.guid,
    context = { name = "Hogger", npcID = 448, rank = "rare" } }
local function CaptionDeath(death)
    local w = Chosen(row, STRANGER.guid, death)
    local said = {}
    ns.UI.JourneyMargin.KINDS.witness.say(said, {}, { witness = w })
    return said
end
Eq(CaptionDeath({ t = mock.now, name = "Timber Wolf" }).death, "a Timber Wolf",
    "the recorded cause wins over the previously targeted creature")
Eq(CaptionDeath({ t = mock.now }).death, nil, "an unknown cause stays unknown")
Eq(CaptionDeath({ t = mock.now, name = "Timber Wolf", probable = true }).death, nil,
    "a probable cause is not upgraded to a confirmed killer")
Eq(CaptionDeath({ t = mock.now, name = "Falling", environment = "FALLING" }).death, nil,
    "a fall is not attributed to the previously targeted creature")

--------------------------------------------------------------------------
Section("the player's own interpretation stays their own")

local before = #ns.Journey.WitnessIndex()
for _, case in ipairs({ { deed = "saw", words = "saw you die" },
    { deed = "tried", words = "tried to save you" }, { deed = "saved", words = "saved you" } }) do
    local rec = { name = "Bram", guid = STRANGER.guid, deed = case.deed,
        creature = "Hogger", bare = "yes", pct = 6, t = mock.now, level = 12 }
    local w = W.Written(rec)
    Eq(w.written, rec, "the authored source stays explicit")
    Eq(W.Deed(w), case.words, "the player's chosen role is preserved")
    Eq(W.Caption(w), "Bram " .. case.words .. ".", "the authored caption remains theirs")
    Eq(W.Foe(w), case.deed == "saw" and "to Hogger" or "from Hogger", "the authored creature remains")
    Eq(Card.Evidence(w), case.deed == "saved" and "chart" or nil, "only the authored rescue keeps its supplied health")
    local _, tip = W.Tip(w, mock.now)
    Check(not table.concat(tip, "|"):find("Had you or a foe targeted", 1, true),
        "authored interpretation never claims automatic observation")
    Eq(rec.deed, case.deed, "reading never changes the authored role")
    Eq(rec.name, "Bram", "reading never changes the authored name")
    Eq(rec.pct, 6, "reading never changes the authored health")
end
Eq(#ns.Journey.WitnessIndex(), before, "authored interpretations never become captured People rows")

--------------------------------------------------------------------------
Section("routine group assistance stays in the expanded episode")

Fresh()
local start, sid = mock.now - 120, 991
ns.Characters.Observe(STRANGER.guid, { first = "Bram", surname = "Redfen" })
ns.Diary.Add(STRANGER.guid, { source = "test" })
ns.db.sessions[sid] = { id = sid, me = SELF.guid, source = "group", startedAt = start,
    endedAt = mock.now, zones = { "Mulgore" }, deaths = {}, others = 0,
    participants = { [STRANGER.guid] = { since = start, last = mock.now, seconds = 120,
        zones = { "Mulgore" } } } }
for i = 1, 3 do
    local at = start + i * 20
    ns.Interactions.Add(STRANGER.guid, W.AID, { time = at, session = sid,
        context = { evidence = 1, method = "meter", action = "heal", healed = 20,
            started = at - 10, ended = at, grouped = true } })
end
ns.Interactions.Add(STRANGER.guid, W.HELPED, { time = mock.now, session = sid,
    context = { evidence = 1, method = "meter", action = "heal", healed = 20,
        started = mock.now - 10, ended = mock.now, grouped = true } })
ns.Touch()
local episode
for _, item in ipairs(ns.Timeline.For(STRANGER.guid)) do
    if item.kind == "session" and item.session.id == sid then episode = item end
end
Check(episode ~= nil, "the existing group episode remains the home for the assistance")
Eq(#episode.all, 4, "expanded history retains every recorded encounter")
Eq(#episode.lines, 1, "routine successful help does not crowd the folded episode")
Eq(episode.lines[1].row.type, W.HELPED, "the fatal attempt remains a visible moment")
local _, help = ns.UI.DescribeItem(episode.all[1], STRANGER.guid)
Check(help:find("healed you during the fight", 1, true), "expanding reveals the exact action")
Eq(ns.Rows.Get(W.AID).moment({ context = { evidence = 1, method = "meter", action = "heal" } }), true,
    "an encounter with someone outside the group remains a visible moment")
