-- Synthetic visits which ended without a boss kill: their observable
-- attempts and deaths can be read without labelling the run a victory.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Text, YD, Run = ns.UI.JourneyText, ns.UI.YourDiary, ns.DungeonRun
local t0 = 1791000000
mock.now = t0 + 3600
mock.SetUnit("player", F.Like(F.SELF, { level = 22 }))

Section("solo and group deaths retain the right subject")
Eq(Text.RunFell(1, true), "you fell once", "one solo death")
Eq(Text.RunFell(2, true), "you fell twice", "two solo deaths")
Eq(Text.RunFell(6, true), "you fell six times", "several solo deaths")
Eq(Text.RunFell(1), "we fell once", "existing group words stay intact")

ns.db.journey[F.SELF.guid] = nil
local j = ns.Journey.Begin(F.SELF.guid, t0, 22, 1413)
local visit = ns.Instances.New({ me = F.SELF.guid, instanceID = 47, name = "Razorfen Kraul",
    startedAt = t0 + 60, endedAt = t0 + 900, bossTotal = 6, bossesKilled = {},
    spans = { { from = t0 + 60, to = t0 + 900 } },
    members = { { guid = F.SELF.guid, first = "Tester", level = 22 } },
    pulls = { { start = t0 + 300, stop = t0 + 330, name = "Aggem Thorncurse", killed = false } },
    deathLog = { { guid = F.SELF.guid, time = t0 + 330, killer = { name = "Aggem Thorncurse" } } } })
j.segments = { { kind = "dungeon", from = t0 + 60, to = t0 + 900, seconds = 840,
    instanceID = 47, name = visit.name, mapID = 1413, x = 0.4, y = 0.6, levelFrom = 22, levelTo = 22 } }
ns.Journey.Touch()

Section("the partial run opens with zero bosses and an honest solo death")
Check(ns.JourneyRecap.RunWorthy(visit), "an observed unsuccessful attempt earns a page")
local killed, total, full = Run.Bosses(visit)
Eq(killed, 0, "no kill is invented")
Eq(total, 6, "the known boss count remains")
Eq(full, false, "the partial run is never marked full")
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
ns.UI.RefreshJourneyPage()
local page = ns.UI.JourneyPage()
YD.OpenRun(visit.id, 1)
Eq(page.mode, "run", "the no-boss visit is reachable")
Eq(page.run.fallenHead:GetText(), "you fell once", "the visible note names the solo owner")
Eq(#page.run.keepsakes.shown, 0, "the run invents no keepsake")
Check(page.run.plan.boss ~= nil, "the existing zero-boss strip can be laid")
local hit
for i = 1, page.run.used.hit.n do
    local h = page.run.used.hit[i]
    if h.pad and h.pad.kind == "fallen" then hit = h end
end
Check(hit ~= nil, "the fallen note keeps its tooltip target")
hit.scripts.OnEnter(hit)
Eq(GameTooltip.text, "you fell once", "the tooltip agrees with the visible note")
Eq(#GameTooltip.lines, 1, "the one observed death is kept once")

Section("adding an observed companion restores group wording")
visit.members[#visit.members + 1] = { guid = "Player-0000-A1000010", first = "Bram", level = 22 }
ns.Touch()
ns.UI.RedrawJourneyPage()
Eq(page.run.fallenHead:GetText(), "we fell once", "a group visit retains its established words")
visit.members = nil
ns.Touch()
ns.UI.RedrawJourneyPage()
Eq(page.run.fallenHead:GetText(), "we fell once", "an absent old roster is not called solo")
