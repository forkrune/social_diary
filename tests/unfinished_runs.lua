-- The visit's story does not depend on a boss kill. Use saved events and
-- measured time inside, never roster size or wall-clock time away.
local T = ...
local F = T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local I, R = ns.Instances, ns.JourneyRecap
local ME = F.SELF.guid

Section("a brief solo attempt survives leaving the dungeon")
local info = { instanceID = 36, name = "The Deadmines", instanceType = "party", difficultyID = 1 }
local attempted = I.Enter(info, 100)
I.Pull(99999, "Stone Watcher", false, 110)
I.PullEnd(99999, "Stone Watcher", false, false, 140)
I.Leave(150)
Eq(I.Close(200), attempted, "a short unsuccessful solo visit was discarded")
Eq(#attempted.bossesKilled, 0, "an attempt became a victory")
Eq(attempted.pulls[1].killed, nil, "a reset became a kill")
Check(R.RunWorthy(attempted), "the retained attempt has no diary page")
Eq(#R.Runs({ visits = { attempted } }, 100, 200), 1, "the attempt was missing from the sitting")
Eq(#R.Runs({ visits = { attempted } }, 150, 200), 0, "a later sitting borrowed the attempt")

Section("a short solo death is kept without a completed boss attempt")
local died = I.Enter(info, 300)
Check(I.Death(ME, nil, 320) ~= nil, "setup did not record the owner's death")
I.Leave(330, true)
Eq(I.Close(340), died, "the short solo death was discarded")
Check(R.RunWorthy(died), "a recorded solo death has no page")
Eq(died.deaths, 1, "the page qualifier changed the death count")

Section("a brief uneventful peek remains a door on the road")
local peek = I.Enter(info, 500)
I.Leave(530)
Eq(I.Close(600), nil, "a brief empty solo visit became permanent")
Eq(R.RunWorthy({ members = { { guid = ME }, { guid = F.STRANGER.guid } },
    startedAt = 100, endedAt = 200, spans = { { from = 100, to = 200 } } }), false,
    "merely sharing the instance became an expedition")
Eq(R.RunWorthy({ pulls = { { start = 100 } } }), false, "an unended pull alone implied an outcome")
Eq(R.RunWorthy({ pulls = { { start = 120, stop = 100 } } }), false, "an invalid interval became an attempt")

Section("only observed time inside earns a quiet visit its own page")
Eq(R.RunWorthy({ spans = { { from = 100, to = 699 } } }), false, "the measured-time boundary")
Eq(R.RunWorthy({ spans = { { from = 100, to = 700 } } }), true, "ten measured minutes are a visit")
Eq(R.RunWorthy({ startedAt = 100, endedAt = 10000 }), false, "legacy elapsed time became measured inside time")
Eq(R.RunWorthy({ startedAt = 100, endedAt = 10000,
    spans = { { from = 100, to = 200 }, { from = 9900, to = 10000 } } }), false,
    "the time outside between two brief entries was counted")
Eq(R.RunWorthy({ spans = { { from = 100, to = 400, ghost = true }, { from = 800, to = 1100 } } }), true,
    "leaving dead erased the play that preceded the corpse run")
Eq(R.RunWorthy({ spans = { { from = 100 } } }), false, "an open span invented elapsed time")
Eq(R.RunWorthy({ spans = { { from = 200, to = 100 } } }), false, "reversed span earned a page")
Eq(R.RunWorthy({ spans = { { from = 100, to = 400 }, { from = 300, to = 600 } } }), false,
    "overlapping samples counted their shared time twice")

Section("the capped last span cannot turn outside time into a quiet visit")
local capped = I.Enter(info, 1000)
for i = 1, 40 do
    local at = 1000 + (i - 1) * 30
    if i > 1 then I.Enter(info, at) end
    I.Leave(at + 5)
end
Eq(#capped.spans, 40, "setup did not fill the bounded span list")
local lastFrom = capped.spans[40].from
I.Enter(info, lastFrom + 1000)
I.Leave(lastFrom + 1005)
Eq(#capped.spans, 40, "the capture's existing span cap changed")
Eq(capped.spans[40].from, lastFrom, "the old last-span semantics were reinterpreted")
Eq(I.ObservedInside(capped), 39 * 5, "an ambiguous capped interval counted as observed play")
Eq(R.RunWorthy(capped), false, "the gap in the capped last span invented a substantial visit")
I.Close(lastFrom + 1010)

Section("authored routes and historical outcomes keep their established meaning")
Eq(R.RunWorthy({ route = { { f = 1, x = 0.3, y = 0.4 } } }), true, "the player's own drawing was lost")
Eq(R.RunWorthy({ route = {} }), false, "an erased drawing still earned a page")
Eq(R.RunWorthy({ bossesKilled = { "Stone Watcher" } }), true, "an old boss kill was lost")
Eq(R.RunWorthy({ inferred = { ["Stone Watcher"] = "loot" } }), true, "an old loot-confirmed kill was lost")
Eq(R.RunWorthy({ deathLog = { { guid = ME, time = 100 } } }), true, "an observed death needs no redundant counter")
Eq(R.RunWorthy(nil), false, "a missing visit earned a page")
local n, total = ns.DungeonRun.Bosses(attempted)
Eq(n, 0, "the dungeon summary called an attempt a kill")
Check(total == nil or n < total, "the zero-kill attempt became a full run")
