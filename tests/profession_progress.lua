-- Observed profession gains: quiet progress without inventing a crafting
-- session, borrowing a hidden baseline or repeating the same cap twice.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local P, J, R = ns.ProfessionCaps, ns.Journey, ns.JourneyRecap
local MINING, AID = 186, 129
local oldError, errors = _G.geterrorhandler, {}
_G.geterrorhandler = function() return function(message) errors[#errors + 1] = tostring(message) end end

local function Skill(rank, max, slot, line, name)
    mock.professions[slot or 1] = { rank = rank, max = max or 75, line = line or MINING, name = name or "Mining" }
end

local function Changed(rank, seconds, max)
    mock.now = mock.now + (seconds or 60)
    if rank ~= nil then Skill(rank, max) end
    ns.Sittings.Note(J.Mine(), mock.now)
    mock.fire("SKILL_LINES_CHANGED")
    mock.fire("CHAT_MSG_SKILL", mock.secret("unread skill text"))
    mock.RunTimers()
end

local function Count(j) return #P.ProgressList(j) end

Section("first reads and a distinct series of gains")
Skill(60)
mock.position, mock.subZone = { x = 0.4, y = 0.6 }, "Amber Meadow"
mock.fire("PLAYER_ENTERING_WORLD")
-- An early skill event cannot arm against a partially loaded world.
Skill(61)
mock.fire("SKILL_LINES_CHANGED")
mock.RunTimers()
local j = J.Mine()
Eq(Count(j), 0, "the initial reading was recorded as progress")
ns.Sittings.Note(j, mock.now)

Changed(62)
Eq(Count(j), 1, "a below-cap gain was lost")
local p = j.skillProgress[1]
Eq(p.fromRank, 61, "the gain did not start at its observed baseline")
Eq(p.rank, 62, "the current rank was lost")
Eq(p.mapID, 1412, "the gain's map")
Eq(p.x, 0.4, "the gain's actual position")
Eq(p.subZone, "Amber Meadow", "the recorded place")
Eq(p.observations, 1, "one gain became repeated observations")
local firstTime = p.t

mock.position = { x = 0.405, y = 0.6 }
Changed(64)
Eq(Count(j), 1, "nearby consecutive gains were not compressed")
Eq(p.fromRank, 61, "compression replaced the observed starting rank")
Eq(p.rank, 64, "compression lost the latest rank")
Eq(p.started, firstTime, "compression lost its first gain time")
Eq(p.t, mock.now, "the marker did not follow the final gain time")
Eq(p.x, 0.405, "the marker did not follow the final gain's actual spot")
Eq(p.startX, 0.4, "the fixed first gain position drifted")
Eq(p.observations, 2, "two positive readings did not remain distinct")
Changed(nil)
Eq(Count(j), 1, "an identical read produced another gain")
Eq(p.observations, 2, "identical readings invented repeated practice")

Section("a cap keeps the measurement and appears once")
Changed(75)
Eq(Count(j), 1, "the cap lost the preceding burst")
Eq(#j.skillCaps, 1, "the original cap capture was lost")
Eq(p.rank, 75, "the final gain was discarded")
Check(not P.ProgressShown(j, p), "a cap and its final gain both became highlights")
Eq(P.CapProgress(j, j.skillCaps[1]), p, "the exact cap did not link its own measured gain")
local e = R.Gather(j, firstTime - 1, mock.now + 1, {})
Eq(#e.skillCaps, 1, "the cap was not gathered")
Eq(#e.skillProgress, 0, "the same occurrence was gathered twice")
local caps, progress = {}, {}
for _, moment in ipairs(R.Moments(j, e, {})) do
    if moment.kind == "skill" then caps[#caps + 1] = moment end
    if moment.kind == "skillProgress" then progress[#progress + 1] = moment end
end
Eq(#caps, 1, "the cap has no moment")
Eq(#progress, 0, "cap suppression did not reach the moment registry")
local selected = R.MOMENTS.skill.selection(caps[1])
Eq(selected.family, "profession", "cap and progress are not one selection family")
Eq(selected.context, "linked", "the exact measured cap link was not available to selection")
Eq(selected.event, p, "the cap link lost its actual source record")
Eq(R.MOMENTS.skill.selection({ cap = { t = 1, rank = 75, skillLine = MINING } }).context, nil,
    "an older cap acquired a fictional baseline")
Check(P.ProgressShown({ skillCaps = { { skillLine = AID, rank = 75, t = p.t } } }, p),
    "another profession's cap swallowed progress")
Check(P.ProgressShown({ skillCaps = { { skillLine = MINING, rank = 75, t = p.t + 1 } } }, p),
    "another time's cap swallowed progress")
Changed(nil)
Eq(#j.skillCaps, 1, "staying at the cap repeated the cap")

Section("training, decreases and incomplete readings reset continuity")
Changed(75, 60, 150)
Eq(Count(j), 1, "training became a gain")
Changed(80, 60, 150)
Eq(Count(j), 2, "progress after training was lost")
Eq(j.skillProgress[2].fromRank, 75, "progress crossed the trainer boundary")
Changed(3, 60, 150)
Eq(Count(j), 2, "a decrease became progress")
Changed(4, 60, 150)
Eq(Count(j), 3, "a gain after a decrease was lost")
Eq(j.skillProgress[3].fromRank, 3, "the old high baseline survived a decrease")

local n = Count(j)
Skill(mock.secret(5), 150)
Changed(nil)
Skill(12, 150)
Changed(nil)
Eq(Count(j), n, "an unreadable rank was bridged by the next readable rank")
Changed(13, 60, 150)
Eq(Count(j), n + 1, "a fresh baseline after secret data could not record a gain")
Eq(j.skillProgress[#j.skillProgress].fromRank, 12, "the secret gap's gain was borrowed")

n = Count(j)
Skill(14, mock.secret(150))
Changed(nil)
Skill(20, 150)
Changed(nil)
Eq(Count(j), n, "an unreadable cap did not invalidate the baseline")
mock.professions = {}
Changed(nil)
Skill(30, 150)
Changed(nil)
Eq(Count(j), n, "an unlearned or unloaded profession did not invalidate the baseline")

local savedAPI = _G.GetProfessionInfo
_G.GetProfessionInfo = nil
Changed(nil)
_G.GetProfessionInfo = savedAPI
Skill(40, 150)
Changed(nil)
Eq(Count(j), n, "an absent API did not invalidate the baseline")
Changed(41, 60, 150)
Eq(j.skillProgress[#j.skillProgress].fromRank, 40, "the API's first reading became a gain")

-- An unreadable profession index must never be passed back into the
-- client API, nor used to bridge the next readable skill value.
n = Count(j)
local savedProfessions = _G.GetProfessions
local calledSecretIndex = false
_G.GetProfessions = function() return mock.secret(1) end
_G.GetProfessionInfo = function(index)
    if issecretvalue(index) then calledSecretIndex = true end
    return savedAPI(index)
end
Changed(nil)
_G.GetProfessions, _G.GetProfessionInfo = savedProfessions, savedAPI
Skill(45, 150)
Changed(nil)
Check(not calledSecretIndex, "an unreadable index reached GetProfessionInfo")
Eq(Count(j), n, "an unreadable profession index left a live baseline")
Changed(46, 60, 150)
Eq(j.skillProgress[#j.skillProgress].fromRank, 45, "the unreadable index's gap was borrowed")

Section("a capture toggle without any skill event is still a gap")
n = Count(j)
local beforeToggle = j.skillProgress[n]
local beforeRank, beforeTime = beforeToggle.rank, beforeToggle.t
ns.JourneyCapture.SetEnabled(false)
Skill(149, 150)
ns.JourneyCapture.SetEnabled(true)
Changed(nil)
Eq(Count(j), n, "disable/re-enable borrowed unobserved gains")
Eq(beforeToggle.rank, beforeRank, "disable/re-enable rewrote an old burst with unobserved gains")
Eq(beforeToggle.t, beforeTime, "disable/re-enable moved an old burst into the hidden interval")
Eq(#j.skillCaps, 1, "disable/re-enable fabricated a cap")
Changed(150, 60, 150)
Eq(Count(j), n + 1, "observed progress after re-arming was lost")
Eq(#j.skillCaps, 2, "the newly observed cap was lost")
Eq(j.skillProgress[#j.skillProgress].fromRank, 149, "the re-armed baseline was not used")

Section("loading screens and stale queued work do not cross baselines")
Changed(150, 60, 225)
Changed(160, 60, 225)
n = Count(j)
Skill(170, 225)
mock.fire("SKILL_LINES_CHANGED")
mock.fire("PLAYER_LEAVING_WORLD")
mock.fire("PLAYER_ENTERING_WORLD")
Skill(180, 225)
mock.RunTimers()
Eq(Count(j), n, "a callback from the old world recorded hidden progress")
Changed(181, 60, 225)
Eq(j.skillProgress[#j.skillProgress].fromRank, 180, "the loading screen's baseline was borrowed")
Eq(j.skillProgress[#j.skillProgress].observations, 1, "a burst crossed the loading screen")

-- The local clock moving backwards cannot manufacture a backwards burst.
n = Count(j)
mock.now = mock.now - 600
Skill(190, 225)
Changed(nil, 0)
Eq(Count(j), n, "a backwards time reading manufactured a gain")
mock.now = mock.now + 700
Changed(191, 0, 225)
Eq(j.skillProgress[#j.skillProgress].fromRank, 190, "the clock reset did not establish a baseline")

Section("bounded records preserve level, sitting, time and place cuts")
local base = ns.DayStart(mock.now) + 12 * 3600
local function One()
    local route = {}
    local rec = P.Progress(route, { rank = 10, max = 75 }, { rank = 11, max = 75, name = "Mining" },
        { t = base, skillLine = MINING, level = 10, sitting = base - 100 },
        { mapID = 1412, x = 0.4, y = 0.6, subZone = "Amber Meadow" })
    return route, rec
end
local boundaries = {
    { name = "level", level = 11 },
    { name = "unreadable level", unknownLevel = true },
    { name = "sitting", sitting = base },
    { name = "unknown sitting", unknownSitting = true },
    { name = "long gap", dt = P.PROGRESS.gap + 1 },
    { name = "map", mapID = 1413 },
    { name = "named place", subZone = "Stillwater Shore" },
    { name = "distant position", x = 0.5 },
    { name = "unreadable position", noPosition = true },
    { name = "instance with no coordinates", instance = true },
}
for _, case in ipairs(boundaries) do
    local route, old = One()
    local level = case.level or 10
    if case.unknownLevel then level = nil end
    local sitting = case.sitting or base - 100
    if case.unknownSitting then sitting = nil end
    local where = { mapID = case.mapID or 1412, x = case.x or 0.4, y = 0.6,
        subZone = case.subZone or "Amber Meadow" }
    if case.noPosition then where.x, where.y = nil, nil end
    if case.instance then where = { instanceID = 36, zone = "The Deadmines" } end
    local next = P.Progress(route, { rank = 11, max = 75 }, { rank = 12, max = 75 },
        { t = base + (case.dt or 60), skillLine = MINING, level = level, sitting = sitting }, where, old)
    Eq(Count(route), 2, case.name .. " boundary merged two records")
    Eq(old.rank, 11, case.name .. " moved an earlier gain into a later entry")
    Eq(next.fromRank, 11, case.name .. " did not keep the next exact comparison")
end

do
    local route, old = One()
    local current = old
    for i = 1, math.floor(P.PROGRESS.span / P.PROGRESS.gap) + 1 do
        current = P.Progress(route, { rank = 10 + i, max = 75 }, { rank = 11 + i, max = 75 },
            { t = base + i * P.PROGRESS.gap, skillLine = MINING, level = 10, sitting = base - 100 },
            { mapID = 1412, x = 0.4, y = 0.6, subZone = "Amber Meadow" }, current)
    end
    Eq(Count(route), 2, "continuous small gaps defeated the overall span bound")
    Check(old.t - old.started <= P.PROGRESS.span, "an old burst grew beyond its span bound")
end

-- A number of small moves must not walk the origin across an entire zone.
do
    local route, old = One()
    local current = old
    for i = 1, 3 do
        current = P.Progress(route, { rank = 10 + i, max = 75 }, { rank = 11 + i, max = 75 },
            { t = base + i * 60, skillLine = MINING, level = 10, sitting = base - 100 },
            { mapID = 1412, x = 0.4 + i * 0.009, y = 0.6, subZone = "Amber Meadow" }, current)
    end
    Eq(Count(route), 2, "consecutive short moves drifted outside the original place")
end

for _, cut in ipairs({ ns.DayStart(base) + 86400, ns.DayStart(base) + 5 * 3600 }) do
    local route = {}
    local first = P.Progress(route, { rank = 10, max = 75 }, { rank = 11, max = 75 },
        { t = cut - 30, skillLine = MINING, level = 10, sitting = cut - 1000 },
        { mapID = 1412, x = 0.4, y = 0.6 })
    P.Progress(route, { rank = 11, max = 75 }, { rank = 12, max = 75 },
        { t = cut + 30, skillLine = MINING, level = 10, sitting = cut - 1000 },
        { mapID = 1412, x = 0.4, y = 0.6 }, first)
    Eq(Count(route), 2, "a calendar or diary-day cut moved earlier gains into a later entry")
end

Section("separate professions, retention and repeated selection evidence")
do
    local route, a = One()
    local b = P.Progress(route, { rank = 20, max = 75 }, { rank = 21, max = 75 },
        { t = base + 30, skillLine = AID, level = 10, sitting = base - 100 },
        { mapID = 1412, x = 0.4, y = 0.6, subZone = "Amber Meadow" })
    P.Progress(route, { rank = 11, max = 75 }, { rank = 12, max = 75 },
        { t = base + 60, skillLine = MINING, level = 10, sitting = base - 100 },
        { mapID = 1412, x = 0.4, y = 0.6, subZone = "Amber Meadow" }, a)
    Eq(route.skillProgress[1], b, "another profession's later record lost chronological order")
    Eq(route.skillProgress[2], a, "an extended burst was not moved to its latest time")
    Eq(R.MOMENTS.skillProgress.selection({ progress = a }).context, "repeated",
        "distinct positive readings lost their selection evidence")
    Eq(R.MOMENTS.skillProgress.selection({ progress = b }).context, nil,
        "a single reading was promoted as repeated")
    Eq(R.MOMENTS.skillProgress.selection({ progress = a }).family, "profession", "progress selection family")
    local gathered = R.Gather(route, base - 1, base + 100, {})
    Eq(#gathered.skillProgress, 2, "ordinary progress did not reach the diary")
end

do
    local route = {}
    for i = 1, P.PROGRESS.cap + 3 do
        P.Progress(route, { rank = 10, max = 75 }, { rank = 11, max = 75 },
            { t = base + i, skillLine = MINING }, {})
    end
    Eq(Count(route), P.PROGRESS.cap, "progress storage is unbounded")
    Eq(route.skillProgress[1].t, base + 4, "progress did not discard its oldest plain record")
end

Section("an inconsistent above-cap reading records neither progress nor a milestone")

local capCount, progressCount = #P.List(j), Count(j)
-- A decrease supplies a fresh, valid baseline without adding a gain.
Changed(74, 60, 75)
Changed(76, 60, 75)
Eq(Count(j), progressCount, "an above-cap reading became ordinary progress")
Eq(#P.List(j), capCount, "an above-cap reading became a false training milestone")
Changed(74, 60, 75)
Eq(Count(j), progressCount, "returning to a readable baseline borrowed the impossible gain")
Changed(75, 60, 75)
Eq(Count(j), progressCount + 1, "a later valid gain after the inconsistent reading was lost")
Eq(#P.List(j), capCount + 1, "the subsequent exact observed cap was lost")
Eq(P.List(j)[#P.List(j)].rank, 75, "the subsequent cap kept the inconsistent rank")

Check(not P.IsProgress({ rank = 75, max = 75 }, { rank = 76, max = 75 }), "an impossible above-cap gain was kept")
Check(not P.IsProgress({ rank = 1, max = 75 }, { rank = 0 / 0, max = 75 }), "NaN was a gain")
Check(not P.IsProgress({ rank = 1, max = 75 }, { rank = math.huge, max = math.huge }), "infinity was a gain")
Check(not P.IsProgress(nil, { rank = 75, max = 75 }), "a missing baseline was a gain")
Check(not P.ValidProgress({ skillLine = MINING, rank = 20 }), "an incomplete saved record became presentable")
Eq(#errors, 0, "a profession event raised an addon error: " .. table.concat(errors, "; "))
_G.geterrorhandler = oldError
