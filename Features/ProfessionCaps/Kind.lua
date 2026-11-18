-- Profession caps (JRN-29): a profession's skill reaching the most its
-- training allows, and where. A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a cap is to the diary: the route's list and the
--                recap's moment
--   Text.lua     its words: the level's prose, the plates' captions, the
--                mark's tooltip
--   Mark.lua     its mark on the plates (a flight of stairs)
--   Capture.lua  the professions read off the client as their skill
--                changes, and a cap reached written down
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a profession's cap. Its own names are on
-- ns.ProfessionCaps, made here, the first of its files the TOC loads. The
-- moment's kind is "skill" and the route's list "skillCaps" ("skill", not
-- "cap": the recap's capAt is the level cap).
--
-- This file: the route's caps and observed skill gains, and the moments
-- that put them on the plates. The older cap records keep their meaning;
-- gains below a cap live on their own optional list, so an update never
-- turns a player's old training milestone into something else.

local addonName, ns = ...

local ProfessionCaps = {}
ns.ProfessionCaps = ProfessionCaps

--------------------------------------------------------------------------
-- The route's list: as far as the training goes
--------------------------------------------------------------------------
--
-- A profession's skill climbs to the most its training allows (75, 150,
-- 225, 300 on Forever: probe 12 Oct) and stops there until the next
-- trainer. Reaching it is the moment kept; training, and learning the
-- profession, are not (the user's choice, 12 Oct).
--
-- j.skillCaps holds each, oldest first: { t, mapID, x, y, level, skillLine,
-- name, rank }. `skillLine` is the client's id for the profession (the
-- same in every language), `name` how the client called it then, `rank`
-- the cap reached. The newest 100 are kept a character.

local Journey = ns.Journey
Journey.RegisterList("skillCaps", { cap = 100 })

-- These are limits on compression and storage, not estimates of how
-- meaningful a skill-up is. Every positive reading can stand on its own.
-- Several nearby readings can share one record only while all the
-- boundaries below still agree. In particular, elapsed time between
-- readings is never counted as time spent practising a profession.
local PROGRESS = {
    cap = 200,           -- newest plain progress records kept a character
    gap = 5 * 60,        -- longest gap between two gains in one record
    span = 20 * 60,      -- longest span from its first gain to its last
    radius = 0.02,       -- map-coordinate distance from the first gain
}
ProfessionCaps.PROGRESS = PROGRESS
Journey.RegisterList("skillProgress", { cap = PROGRESS.cap })

local function Whole(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

-- The skill rose under one unchanged training cap. A missing reading,
-- training, a decrease or a not-yet-loaded zero cap is no measured gain.
-- The capture takes a fresh baseline after each of those boundaries.
function ProfessionCaps.IsProgress(before, now)
    return before ~= nil and now ~= nil
        and Whole(before.rank) and Whole(now.rank) and Whole(now.max) and now.max > 0
        and before.max == now.max and before.rank < now.rank and now.rank <= now.max
end

-- The minimum facts the presentation may read. There are no old-shaped
-- progress records to reinterpret, and an incomplete record is not a
-- licence to fill in a starting skill or a method such as crafting.
function ProfessionCaps.ValidProgress(rec)
    return type(rec) == "table" and Whole(rec.skillLine) and rec.skillLine > 0
        and Whole(rec.t) and Whole(rec.started) and rec.started <= rec.t
        and Whole(rec.fromRank) and Whole(rec.rank) and Whole(rec.max) and rec.max > 0
        and rec.fromRank < rec.rank and rec.rank <= rec.max
end

local function SamePlace(rec, spot, where)
    if not (rec.mapID and rec.mapID == spot.mapID
        and type(rec.startX) == "number" and type(rec.startY) == "number"
        and type(spot.x) == "number" and type(spot.y) == "number") then
        return false
    end
    if rec.subZone ~= (where and where.subZone) then return false end
    local dx, dy = spot.x - rec.startX, spot.y - rec.startY
    return dx * dx + dy * dy <= PROGRESS.radius * PROGRESS.radius
end

local function SameDay(first, last)
    -- A level's sitting may cross midnight, while a capped character's
    -- weekly entry may not. Keeping both calendar and diary-day cuts
    -- prevents the last gain from carrying earlier ones over either cut.
    return ns.DayStart(first) == ns.DayStart(last)
        and ns.JourneyRecap.SittingDay(first) == ns.JourneyRecap.SittingDay(last)
end

-- One live gain, or the continuation of `previous`, a record made by
-- this capture since its last boundary. `info` is { t, skillLine, level,
-- sitting }; `sitting` is that sitting's start, not a together session.
-- A missing level, sitting or readable position permits a record, but
-- never joins it to another. The marker is the latest gain's actual spot;
-- startX/startY retain the first gain's spot and prevent gradual drift.
function ProfessionCaps.Progress(j, before, now, info, where, previous)
    if not (j and info and Whole(info.skillLine) and info.skillLine > 0
        and ProfessionCaps.IsProgress(before, now)) then return nil end
    local t = info.t or ns.Now()
    if not Whole(t) then return nil end
    local spot = Journey.Spot(where)
    local list, index = Journey.List(j, "skillProgress"), nil
    for i = #list, 1, -1 do
        if list[i] == previous then index = i; break end
    end
    local merge = index and ProfessionCaps.ValidProgress(previous)
        and previous.skillLine == info.skillLine and previous.rank == before.rank and previous.max == now.max
        and Whole(info.level) and info.level > 0 and previous.level == info.level
        and Whole(info.sitting) and previous.sitting == info.sitting
        and t > previous.t and t - previous.t <= PROGRESS.gap and t - previous.started <= PROGRESS.span
        and SameDay(previous.started, t) and SamePlace(previous, spot, where)
    if merge then
        previous.t, previous.rank = t, now.rank
        previous.name = now.name or previous.name
        previous.x, previous.y = spot.x, spot.y
        previous.observations = (Whole(previous.observations) and previous.observations or 1) + 1
        -- A second profession may have changed between these readings.
        -- Keep the list oldest first when this record's end moves later.
        table.remove(list, index)
        list[#list + 1] = previous
        Journey.Touch()
        return previous
    end
    return Journey.Append(j, "skillProgress", {
        t = t, started = t, skillLine = info.skillLine, name = now.name,
        fromRank = before.rank, rank = now.rank, max = now.max, observations = 1,
        level = info.level, sitting = info.sitting, subZone = where and where.subZone,
        startX = spot.x, startY = spot.y,
    }, where)
end

function ProfessionCaps.ProgressList(j)
    return Journey.List(j, "skillProgress")
end

-- A cap and the final observed gain are one occurrence on the page.
-- Keep both measurements in storage, but prefer the existing cap's
-- words and mark when that exact cap is still on the route. A cap with a
-- different time or profession must not swallow this progress.
function ProfessionCaps.ProgressShown(j, rec)
    if not ProfessionCaps.ValidProgress(rec) then return false end
    for _, cap in ipairs(Journey.List(j, "skillCaps")) do
        if cap.skillLine == rec.skillLine and cap.t == rec.t and cap.rank == rec.rank then return false end
    end
    return true
end

-- The measured rise ending at this cap, when capture kept both. This is
-- a read-only link, not a baseline invented for an older cap record.
function ProfessionCaps.CapProgress(j, cap)
    local list = ProfessionCaps.ProgressList(j)
    for i = #list, 1, -1 do
        local p = list[i]
        if ProfessionCaps.ValidProgress(p) and p.skillLine == cap.skillLine and p.t == cap.t
            and p.rank == cap.rank then return p end
    end
    return nil
end

-- Whether a profession went from below its cap to it between two
-- readings, each { rank, max }. Only a rank that climbed under a max that
-- stayed put: a max that moved is training, or a reading not loaded yet.
-- A rank beyond that maximum is an inconsistent reading, not evidence
-- that a training milestone was reached. Saved caps keep their old words;
-- this predicate only decides which new measurements can establish one.
function ProfessionCaps.IsCap(before, now)
    return ProfessionCaps.IsProgress(before, now) and now.rank == now.max
end

-- A cap reached on route `j`, here and now unless `where` says otherwise
-- (in ns.Where's shape; nowhere inside an instance, where the recap places
-- it by time). `rec` is { t, level, skillLine, name, rank }.
function ProfessionCaps.Add(j, rec, where)
    if not (j and rec and rec.skillLine and rec.rank) then return nil end
    return Journey.Append(j, "skillCaps", { t = rec.t, level = rec.level, skillLine = rec.skillLine,
        name = rec.name, rank = rec.rank }, where)
end

-- A character's profession caps, oldest first.
function ProfessionCaps.List(j)
    return Journey.List(j, "skillCaps")
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A profession at its cap, where the last skill-up came; one reached in a
-- dungeon has no spot of its own, and is placed by the route at its time.
--
-- Rank 2, with a first found and a chain's finale (Core/JourneyRecap.lua's
-- RANK, Decision 10): after the people you were with (1), before a death,
-- a close call and luck (3), and well before the level's pin (8), as a
-- level is reached anyway. Light: its words are all it has, with no card in the
-- margin (the user's choice, 13 Oct), so a plate of caps and places alone
-- is given a print, not a full slot. Its order (60) puts it after the
-- chains' ends among the features' moments.
ns.JourneyRecap.RegisterMoment("skill", { order = 60, list = "skillCaps", field = "cap", rank = 2, light = true,
    moment = function(j, cap, Own)
        local map, x, y = Own(j, cap.mapID, cap.x, cap.y, cap.t)
        return { kind = "skill", t = cap.t, cap = cap, progress = ProfessionCaps.CapProgress(j, cap) }, map, x, y
    end,
    selection = function(m)
        return { family = "profession", event = m.progress or m.cap, context = m.progress and "linked" or nil }
    end })

-- Below-cap progress is a quiet moment in its own right. Repeated here
-- means two distinct positive readings, never two polls of the same
-- skill, and affects selection only: it says nothing about effort or
-- how the skill was raised. The cap occurrence is not offered twice.
ns.JourneyRecap.RegisterMoment("skillProgress", { order = 61, entry = "skillProgress", field = "progress",
    rank = 5, light = true,
    gather = function(j, a, b, e)
        e.skillProgress = {}
        for _, rec in ipairs(ProfessionCaps.ProgressList(j)) do
            if ProfessionCaps.ProgressShown(j, rec) and rec.t >= a and rec.t < b then
                e.skillProgress[#e.skillProgress + 1] = rec
            end
        end
    end,
    selection = function(m)
        local p = m.progress
        return { family = "profession", event = p,
            context = ProfessionCaps.ValidProgress(p) and Whole(p.observations) and p.observations >= 2
                and "repeated" or nil }
    end,
})
