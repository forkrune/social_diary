-- Witness detection from continuous observations, followed through its
-- existing timeline/card/picker surfaces. Attributed assistance and guarded
-- damage-meter scenarios have their own integration cases in witness_detection.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local W = ns.Witnesses
local SELF, STRANGER, FRIEND, PUG, HOSTILE = F.SELF, F.STRANGER, F.FRIEND, F.PUG, F.HOSTILE
local STRANGER2, GARRICK = F.STRANGER2, F.GARRICK
local STRIDER = "Creature-0-4615-1-832-2955-00004B69A3"
local STRIDER2 = "Creature-0-4615-1-832-2955-00004B69A4"
local WOLF = "Creature-0-4615-1-832-2958-00004B6A01"

local fighting, dead, afk = {}, {}, {}
_G.UnitAffectingCombat = function(unit)
    if unit == "player" then return mock.inCombat end
    local def = mock.units[unit]
    if not def then return false end
    if fighting[def.guid] ~= nil then return fighting[def.guid] end
    return def.isPlayer == false and mock.inCombat or false
end
_G.UnitIsDeadOrGhost = function(unit)
    if unit == "player" then return mock.dead or mock.ghost end
    local def = mock.units[unit]
    return def and dead[def.guid] or false
end
_G.UnitIsAFK = function(unit)
    local def = mock.units[unit]
    return def and afk[def.guid] or false
end
_G.GetTime = function() return mock.now end

local function Mob(guid, name)
    return { guid = guid, name = { name }, isPlayer = false, hostile = true }
end
local function Plate(i, who, target)
    mock.SetUnit("nameplate" .. i, who)
    mock.SetUnit("nameplate" .. i .. "target", target)
    mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
end
local function Target(guid)
    mock.SetUnit("target", Mob(guid or STRIDER, "Plainstrider"))
    mock.SetUnit("targettarget", SELF)
    mock.fire("PLAYER_TARGET_CHANGED")
end
local function Pass(seconds)
    for _ = 1, seconds do
        mock.now = mock.now + 1
        ns._test.WitnessesScan()
    end
end
local function Fresh()
    mock.dead, mock.ghost, mock.feigning, mock.inCombat = false, false, false, false
    mock.fire("PLAYER_ENTERING_WORLD", false, false)
    mock.fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 6 do mock.RunTimers() end
    T.BlankDiary()
    mock.ClearUnits()
    mock.SetUnit("player", SELF)
    fighting, dead, afk = {}, {}, {}
    mock.now = mock.now + 60
end
local function Start()
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
    Target()
end
local function Die()
    mock.dead = true
    mock.fire("PLAYER_DEAD")
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 6 do mock.RunTimers() end
end
local function Line(guid, kind)
    local row = ns._test.LatestInteraction(guid, kind)
    if not row then return nil end
    local _, text = ns.UI.DescribeItem({ kind = "row", row = row }, guid)
    return (text:gsub("\194\160", " "))
end
local function Rows(guid)
    return T.Rows(guid, W.WATCHED) + T.Rows(guid, W.HELPED) + T.Rows(guid, W.SAVED)
        + T.Rows(guid, W.AID)
end

mock.now = 1792000000
mock.zone = "Mulgore"
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.RunTimers()

--------------------------------------------------------------------------
Section("a continuous witness is retained with evidence")

Fresh()
Start()
Plate(1, STRANGER, SELF)
Pass(3)
Die()
local row = ns._test.LatestInteraction(STRANGER.guid, W.WATCHED)
Check(row ~= nil, "a continuously observed witness was omitted")
Eq(row.context.evidence, 1, "new observations are distinguishable from old rows")
Eq(row.context.method, "target_streak", "the observation basis survives")
Eq(row.context.action, "witness", "targeting is not a helpful action")
Eq(row.context.watched, 3, "only the unbroken sampled interval is kept")
Eq(Line(STRANGER.guid, W.WATCHED), "Bram watched you die in Mulgore", "the original sustained-witness wording")
mock.fire("PLAYER_DEAD")
mock.fire("PLAYER_REGEN_ENABLED")
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "duplicate death/end events duplicate the witness")

--------------------------------------------------------------------------
Section("fresh presence is required through the death")

local missing = {
    { name = "a first sample at death", before = function() end,
        after = function() Plate(1, STRANGER, SELF) end },
    { name = "a stale sample", before = function() Plate(1, STRANGER, SELF); Pass(2) end,
        after = function() mock.now = mock.now + 10 end },
    { name = "a changed target", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() Plate(1, STRANGER, Mob(WOLF, "Timber Wolf")); Pass(1) end },
    { name = "a removed unit", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() mock.SetUnit("nameplate1", nil); mock.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1") end },
    { name = "a hidden unit", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() mock.SetUnit("nameplate1", F.Like(STRANGER, { visible = false })) end },
    { name = "a dead witness", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() dead[STRANGER.guid] = true end },
    { name = "an AFK witness", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() afk[STRANGER.guid] = true end },
    { name = "an unknown combat flag", before = function() Plate(1, STRANGER, SELF); Pass(3) end,
        after = function() fighting[STRANGER.guid] = mock.secret(false) end },
}
for _, case in ipairs(missing) do
    Fresh()
    Start()
    case.before()
    case.after()
    Die()
    Eq(Rows(STRANGER.guid), 0, case.name .. " became a witness or helper")
end

--------------------------------------------------------------------------
Section("one foe is identified by GUID, not by its name")

Fresh()
Start()
Plate(1, STRANGER, Mob(STRIDER, "Plainstrider"))
Plate(2, GARRICK, Mob(STRIDER2, "Plainstrider"))
Plate(3, HOSTILE, SELF)
Pass(3)
Die()
Eq(T.Rows(STRANGER.guid, W.WATCHED), 1, "the particular observed foe is relevant")
Eq(Rows(GARRICK.guid), 0, "a different creature with the same name was conflated")
Eq(Rows(HOSTILE.guid), 0, "an enemy was called a friendly witness")

Fresh()
Start()
Plate(1, STRANGER, SELF)
Pass(6)
Plate(1, STRANGER, Mob(WOLF, "Timber Wolf"))
Pass(1)
Plate(1, STRANGER, SELF)
Pass(2)
Die()
row = ns._test.LatestInteraction(STRANGER.guid, W.WATCHED)
Eq(row and row.context.watched, 2, "a resumed look incorrectly adds the earlier streak")

--------------------------------------------------------------------------
Section("mere target and combat snapshots never imply help")

for _, died in ipairs({ false, true }) do
    Fresh()
    Start()
    local from = mock.now
    Plate(1, STRANGER, Mob(STRIDER, "Plainstrider"))
    Pass(1)
    fighting[STRANGER.guid] = true
    Plate(1, STRANGER, Mob(WOLF, "Timber Wolf"))
    Pass(3)
    if died then Die() else
        mock.inCombat = false
        mock.fire("PLAYER_REGEN_ENABLED")
        ns.Fire("SD_FIGHT_SURVIVED", from, mock.now, 99, 100, { npcID = 2955, name = "Plainstrider" })
        for _ = 1, 6 do mock.RunTimers() end
    end
    Eq(Rows(STRANGER.guid), 0, "unrelated observations became assistance")
end

Fresh()
Start()
Plate(1, STRANGER, SELF)
Pass(3)
mock.fire("UNIT_DIED", STRIDER)
for _ = 1, 6 do mock.RunTimers() end
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
ns.Fire("SD_FIGHT_SURVIVED", mock.now - 3, mock.now, 150, 100)
for _ = 1, 6 do mock.RunTimers() end
Eq(Rows(STRANGER.guid), 0, "a missing group-kill event invented a rescue")

--------------------------------------------------------------------------
Section("environmental deaths need an earlier observation too")

Fresh()
Plate(1, STRANGER, SELF)
Pass(2)
Die()
row = ns._test.LatestInteraction(STRANGER.guid, W.WATCHED)
Check(row ~= nil, "a pre-observed witness to an out-of-combat death was lost")
Eq(row.context.name, nil, "an environmental death names no guessed creature")

Fresh()
mock.SetUnit("target", STRANGER)
mock.SetUnit("targettarget", SELF)
Die()
Eq(Rows(STRANGER.guid), 0, "the death handler invented a pre-death observation")

Fresh()
Start()
Plate(1, STRANGER, SELF)
Pass(2)
mock.feigning = true
mock.fire("PLAYER_DEAD")
Eq(Rows(STRANGER.guid), 0, "Feign Death became a witness story")
mock.feigning = false

--------------------------------------------------------------------------
Section("capture still runs after the reunion toast")

Fresh()
ns.Characters.Forget(STRANGER.guid)
wipe(ns.db.meta.greeted)
ns.Characters.Observe(STRANGER.guid, { first = "Bram" })
ns.Diary.Add(STRANGER.guid, { source = "test" })
Eq(ns.Characters.FullName(STRANGER.guid), "Bram", "setup: surname already known")
Start()
Plate(1, STRANGER, SELF)
Eq(ns.Characters.FullName(STRANGER.guid), "Bram Redfen", "capture did not read the player's identity")
mock.inCombat = false
mock.fire("PLAYER_REGEN_ENABLED")
local toast = ns.UI.ReunionShowing()
Eq(toast and toast.name, "Bram", "capture ran before the toast took its original snapshot")
mock.RunTimers()

--------------------------------------------------------------------------
Section("on the plates: a witness before the killer")

-- The rows find their death or close call by time (ns.Witnesses.At, over
-- the core's Journey.WitnessIndex, which goes by Rows' `witness` flag),
-- and the plate picks one (ns.Witnesses.Card.Choose): who acted before
-- who watched, then the longer watcher.
Fresh()
local t0 = mock.now
ns.Interactions.Add(STRANGER.guid, W.WATCHED, { time = t0, context = { watched = 6.2, name = "Kobold Vermin", npcID = 6 } })
ns.Interactions.Add(GARRICK.guid, W.WATCHED, { time = t0 + 1, context = { watched = 2 } })
ns.Interactions.Add(FRIEND.guid, W.HELPED, { time = t0 + 600, context = { name = "Kobold Vermin", npcID = 6 } })
ns.Interactions.Add(STRANGER2.guid, W.SAVED, { time = t0 + 1200, context = { pct = 11, name = "Burly Rockjaw Trogg" } })
local index = ns.Journey.WitnessIndex()
Eq(#index, 4, "the index")
local at = W.At(index, t0, { watched_death = true, tried_to_help = true })
Eq(#at, 2, "both watchers of the first death")
Eq(at[1].guid, STRANGER.guid, "the longer watcher first")
Eq(#W.At(index, t0 + 10, { watched_death = true }), 0, "a death ten seconds on had watchers")
Eq(#W.At(index, t0 + 1200, { watched_death = true, tried_to_help = true }), 0,
    "a rescue was a death's witness")

local Card = W.Card
local function OnPage(x, y) return x + 100, y + 200 end
local first = { t = t0 }
local second = { t = t0 + 600 }
local crosses = { { x = 10, y = 20, deaths = { first } }, { x = 30, y = 40, deaths = { second } } }
local w = Card.Choose(crosses, {}, index, OnPage)
Eq(w and w.guid, FRIEND.guid, "who tried to save you goes before who watched")
Eq(w.kind, "helped", "kind")
Eq(w.death, second, "the death")
Eq(w.mark[1] .. "," .. w.mark[2], "130,240", "where its cross is on the page")
Eq(w.creature and w.creature.name, "Kobold Vermin", "the creature")
w = Card.Choose({ crosses[1] }, {}, index, OnPage)
Eq(w.guid, STRANGER.guid, "the longer watcher")
Eq(w.watched, 6.2, "how long")
Eq(w.others, 1, "one more watched")
local call = { t = t0 + 1200, pct = 11 }
w = Card.Choose({}, { { at = { 5, 6 }, list = { { call = call } } } }, index, OnPage)
Eq(w and w.type, W.SAVED, "a rescue on a close call")
Eq(w.call, call, "its close call")
Eq(w.pct, 11, "health left")
Eq(Card.Choose({ { x = 0, y = 0, deaths = { { t = t0 + 3000 } } } }, {}, index, OnPage), nil, "nobody was there")

--------------------------------------------------------------------------
Section("the picker's reasons")

Fresh()
ns.Interactions.Add(STRANGER.guid, W.WATCHED, {})
ns.Interactions.Add(FRIEND.guid, W.HELPED, {})
ns.Interactions.Add(STRANGER2.guid, W.SAVED, {})
local reasons = {}
for _, c in ipairs(ns.Candidates()) do reasons[c.guid] = c.why end
Eq(reasons[STRANGER.guid], "they were seen around the time you died", "watched")
Eq(reasons[FRIEND.guid], "they were seen around the time you died", "tried to save")
Eq(reasons[STRANGER2.guid], "they were seen during a fight you survived", "saved")

-- What each witness did, as Core/Rows.lua's `witness` says it: the core's
-- index of witnesses goes by it (Journey.WitnessIndex), the plate's choice
-- by "helped" before "watched".
Eq(ns.Rows.Get(W.WATCHED).witness, "watched", "a watcher's flag")
Eq(ns.Rows.Get(W.HELPED).witness, "helped", "a helper's flag")
Eq(ns.Rows.Get(W.SAVED).witness, "helped", "a rescuer's flag")
