-- A derived feature can prepare one bounded index for a complete read,
-- rather than scanning unlimited interaction history once per level. The
-- original context and source rows remain untouched, and the next read
-- cannot reuse an index from before a removal, backfill or forgotten name.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local R, J, W = ns.JourneyRecap, ns.Journey, ns.Witnesses
local ME, A = F.SELF.guid, F.STRANGER.guid
local base = mock.now

local function Aid(t)
    return { type = W.AID, me = ME, time = t, myLevel = 12, mapID = 1412, x = 0.4, y = 0.5,
        context = { evidence = 1, method = "meter", action = "heal", amount = 30, healed = 30,
            started = t - 20, ended = t } }
end

local function Route()
    return { startedAt = base, startLevel = 1, levels = {
        [2] = { at = base + 100 }, [3] = { at = base + 200 }, [4] = { at = base + 300 },
    }, segments = {}, marks = {} }
end

local function Context()
    return { me = ME, now = base + 400, level = 4, maxLevel = 60, sessions = {}, notes = {}, visits = {},
        characters = { [A] = { first = "Bram" } }, interactions = {}, diary = {}, label = "before" }
end

local rawContext, preparations, gathers = nil, 0, 0
local received, batches = {}, {}
R.RegisterMoment("readProbe", { order = 999, entry = "readProbe", field = "probe", rank = 9, light = true,
    prepare = function(j, ctx)
        preparations = preparations + 1
        Check(ctx ~= rawContext, "a preparation received the caller's context table")
        Eq(ctx.interactions, rawContext.interactions, "a shallow context copied the source store")
        local data = { route = j, serial = preparations, label = ctx.label }
        batches[#batches + 1] = data
        return data
    end,
    gather = function(j, a, b, e, ctx, data)
        gathers = gathers + 1
        Check(data ~= nil, "the gather did not receive its preparation")
        Eq(data.route, j, "a preparation was borrowed from another route")
        received[#received + 1] = data
        e.readProbe[1] = { t = a, serial = data.serial, label = data.label }
    end,
})

local function Begin(ctx)
    rawContext, preparations, gathers, received, batches = ctx, 0, 0, {}, {}
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

Section("Build prepares once for every entry in the read")
local j, ctx = Route(), Context()
Begin(ctx)
local keys, version, routeVersion = CountKeys(ctx), ns.dataVersion, J.version
local recap = R.Build(j, ctx)
Eq(#recap.entries, 4, "the fixture did not exercise several entries")
Eq(preparations, 1, "Build rebuilt a feature index for every entry")
Eq(gathers, 4, "Build did not gather each level")
for _, data in ipairs(received) do Eq(data, batches[1], "the levels did not share one read's preparation") end
Eq(CountKeys(ctx), keys, "the caller context acquired a private preparation marker")
Eq(ns.dataVersion, version, "preparation wrote the diary")
Eq(J.version, routeVersion, "preparation wrote the route")
Eq(next(ctx.interactions), nil, "preparation populated an empty source store")

Section("Pieces prepares once for all sitting cuts")
j.sittings = ns.Sittings.Lines({ { from = base, to = base + 150 }, { from = base + 200, to = base + 400 } })
local entry = { from = base, to = base + 400, kind = "level", known = true, level = 1, current = true }
Begin(ctx)
local pieces = R.Pieces(j, entry, ctx)
Eq(#pieces, 2, "the fixture did not exercise separate sitting cuts")
Eq(preparations, 1, "Pieces rebuilt a feature index for every sitting")
Eq(gathers, 2, "Pieces did not gather both sittings")
Eq(received[1], received[2], "sittings did not share their read's preparation")
Eq(CountKeys(ctx), keys, "Pieces marked the original context")

Section("a reused raw context always prepares afresh")
Begin(ctx)
local one = R.Gather(j, base, base + 100, ctx)
local firstBatch = batches[1]
ctx.label = "after"
local two = R.Gather(j, base, base + 100, ctx)
Eq(preparations, 2, "direct Gather cached the first read on the caller context")
Check(batches[2] ~= firstBatch, "a later read reused an old preparation object")
Eq(one.readProbe[1].label, "before", "a later read rewrote an earlier result")
Eq(two.readProbe[1].label, "after", "the new context value was hidden by a stale index")
Eq(CountKeys(ctx), keys, "a direct Gather marked the original context")

Section("backfilled aid is indexed by time without sorting its source")
local late, early = Aid(base + 250), Aid(base + 50)
ctx.interactions[A] = { late }
Begin(ctx)
local before = R.Gather(j, base, base + 100, ctx)
Eq(#before.assistance, 0, "a later observation leaked into an early range")
ctx.interactions[A][2] = early
local after = R.Gather(j, base, base + 100, ctx)
Eq(#after.assistance, 1, "a late-appended early observation was skipped")
Eq(after.assistance[1].row, early, "the derived observation lost its exact source row")
Eq(ctx.interactions[A][1], late, "the source interaction list was sorted in place")
Eq(ctx.interactions[A][2], early, "the source backfill was moved")
Eq(late.time, base + 250, "preparation rewrote a source timestamp")
Eq(early.context.healed, 30, "preparation rewrote a contribution")
Eq(early.context.amount, 30, "preparation accumulated a replayed amount")
Eq(j.assistance, nil, "derived assistance was copied into saved route data")

-- A direct feature gather, without the registry supplying a preparation,
-- remains useful to its own tests and readers.
local direct = { closeCalls = {} }
R.MOMENTS.assisted.gather(j, base, base + 100, direct, ctx)
Eq(#direct.assistance, 1, "the feature's direct gather lost its standalone contract")
Eq(direct.assistance[1].row, early, "the direct gather changed its source")

Section("aid scans once across Build, then reads exact ranges")
Begin(ctx)
local evidence, calls = W.AidEvidence, 0
W.AidEvidence = function(c) calls = calls + 1; return evidence(c) end
local built = R.Build(j, ctx)
W.AidEvidence = evidence
Eq(calls, 2, "Build rescanned aid evidence for each entry")
Eq(#built.entries[1].assistance, 1, "the early entry lost its aid")
Eq(#built.entries[2].assistance, 0, "the middle range borrowed adjacent aid")
Eq(#built.entries[3].assistance, 1, "the later entry lost its aid")
Eq(#built.entries[4].assistance, 0, "the last range borrowed adjacent aid")

-- Removing a source or forgetting its character, even by replacing a
-- nested store in a reused test context, is visible on the very next read.
ctx.interactions[A] = { late }
Eq(#R.Gather(j, base, base + 100, ctx).assistance, 0, "a removed backfill survived in an old index")
ctx.characters[A] = nil
Eq(#R.Gather(j, base + 200, base + 300, ctx).assistance, 0, "a forgotten character survived in an old index")

Section("source removal invalidates a cached recap for a stranger")
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
local mine = J.Mine()
mock.now = mock.now + 100
mock.SetUnit("target", F.STRANGER)
ns.Characters.ObserveUnit("target")
local function Add(t)
    return ns.Interactions.Add(A, W.AID, { time = t, context = Aid(t).context,
        where = { mapID = 1412, x = 0.4, y = 0.5 }, session = false })
end
local function Total(recap)
    local n = 0
    for _, e in ipairs(recap.entries) do n = n + #e.assistance end
    return n
end
-- The generic probe sees the new context copies here; these checks concern
-- invalidation and not pointer equality to the earlier fixture context.
R.MOMENTS.readProbe.prepare = nil
R.MOMENTS.readProbe.gather = function() end
local row = Add(mock.now - 20)
Check(not ns.Diary.IsDiary(A), "the fixture accidentally uses a permanent diary member")
local cached = R.For(ME)
Eq(Total(cached), 1, "the cached recap did not contain the source observation")
Eq(R.For(ME), cached, "the unchanged fixture was not cached")
local seen = ns.seenVersion
Check(ns.Interactions.Remove(A, row), "the source row was not removed")
Eq(ns.seenVersion, seen + 1, "removing a stranger's row did not invalidate derived reads")
local removed = R.For(ME)
Check(removed ~= cached, "the recap cache survived source removal")
Eq(Total(removed), 0, "the removed contribution remained in the owner's story")
seen = ns.seenVersion
Check(not ns.Interactions.Remove(A, row), "removing an absent row reported another write")
Eq(ns.seenVersion, seen, "an unsuccessful removal needlessly invalidated the recap")

Section("pruning and direct forgetting also invalidate derived reads")
mine.startedAt = mock.now - 100 * T.DAY
J.Touch()
local old = Add(mock.now - 90 * T.DAY)
local stale = R.For(ME)
Eq(Total(stale), 1, "the old source was not present before pruning")
seen = ns.seenVersion
local dropped = ns.Interactions.Prune(mock.now)
Eq(dropped, 1, "the old stranger's interaction was not pruned")
Eq(ns.seenVersion, seen + 1, "pruning did not invalidate derived reads")
Eq(Total(R.For(ME)), 0, "pruned aid survived in the cached recap")
Eq(old.context.healed, 30, "pruning rewrote an observation rather than removing its source")

Add(mock.now - 10)
Eq(Total(R.For(ME)), 1, "the new observation was not captured")
seen = ns.seenVersion
Check(ns.Interactions.Forget(A), "direct forgetting did not remove the source")
Eq(ns.seenVersion, seen + 1, "direct forgetting did not invalidate derived reads")
Eq(Total(R.For(ME)), 0, "directly forgotten aid survived in the cache")
Add(mock.now - 5)
Eq(Total(R.For(ME)), 1, "the final fixture observation was not captured")
seen = ns.seenVersion
Check(ns.Interactions.Forget(nil), "forget-all did not clear the source store")
Eq(ns.seenVersion, seen + 1, "forget-all did not invalidate derived reads")
Eq(Total(R.For(ME)), 0, "forget-all left a derived contribution behind")
