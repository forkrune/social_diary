-- A page should recognise different observed experiences without mistaking
-- more faces or pins for a more memorable event. These are selection-policy
-- checks, not measurements of how strongly a real player remembers anything.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local R, J = ns.JourneyRecap, ns.Journey
local originalMoments = R.Moments
local MAP, OTHER = 1412, 1413

local function Moment(kind, t, x, map, fields)
    local m = { kind = kind, t = t, mapID = map or MAP, x = x, y = 0.5 }
    for key, value in pairs(fields or {}) do m[key] = value end
    return m
end

local function Plates(moments)
    R.Moments = function()
        local copy = {}
        for i, m in ipairs(moments) do copy[i] = m end
        return copy
    end
    local ok, result = pcall(R.Plates, {}, {}, {}, function() return 0.2, 0.2 end)
    R.Moments = originalMoments
    if not ok then error(result) end
    return result
end

local function Has(plates, moment)
    for _, plate in ipairs(plates) do
        for _, m in ipairs(plate.moments) do if m == moment then return plate end end
    end
end

local function Signature(plates)
    local out = {}
    for _, plate in ipairs(plates) do
        local parts = { plate.mapID, plate.t, plate.x0, plate.x1 }
        for _, m in ipairs(plate.moments) do parts[#parts + 1] = m.kind .. ":" .. (m.guid or m.t) end
        out[#out + 1] = table.concat(parts, ",")
    end
    return table.concat(out, "|")
end

-- A throwaway registry entry proves the hook works without core knowing
-- the feature's name or the meaning of its private record fields.
local probe = "memory_selection_probe"
R.RegisterMoment(probe, { order = 999, entry = probe, field = "record", rank = 2,
    selection = function(m)
        return { family = m.record.family, event = m.record.event or m.record,
            context = m.record.context }
    end })

--------------------------------------------------------------------------
Section("authorship and observed context lead the choice")

local ordinary = {}
for i = 1, 4 do
    ordinary[i] = Moment("session", 100 + i, (i - 1) * 0.25 + 0.1, MAP,
        { guid = "Player-0000-MEM00001", session = { id = i } })
end
local manual = Moment("note", 500, 0.1, OTHER,
    { guid = "Player-0000-MEM00002", note = { id = 1, text = "The old bridge was enough for today." } })
local linked = Moment(probe, 600, 0.4, OTHER,
    { record = { family = "contribution", context = "linked" } })
local quiet = Moment("stay", 700, 0.8, OTHER, { seconds = 3600 })
local candidates = { ordinary[1], ordinary[2], ordinary[3], ordinary[4], manual, linked, quiet }
local selected = Plates(candidates)
Eq(#selected, 3, "the existing three-place bound remains")
Check(Has(selected, manual), "the player's own note has a place")
Check(Has(selected, linked), "explicitly connected observations outrank routine company")
Check(not Has(selected, quiet), "a quiet fallback displaces no substantive observation")
for i = 2, #selected do Check(selected[i - 1].t <= selected[i].t, "the chosen account stays chronological") end
Eq(manual.note.text, "The old bridge was enough for today.", "selection never rewrites an authored note")
Eq(#candidates, 7, "selection removes no source candidates")
Eq(ordinary[1].session.selection, nil, "selection writes no metadata into its source session")

local edited = Moment(probe, 900, 0.8, OTHER,
    { record = { family = "quiet", customOf = { t = 900 } } })
Check(R.Selection(edited).authored, "an edited feature card is authored too")
Check(Has(Plates({ ordinary[1], ordinary[2], ordinary[3], linked, edited }), edited),
    "automatic context cannot push out an edited card")

--------------------------------------------------------------------------
Section("different observed experiences survive repeated company")

local solo = Moment(probe, 500, 0.4, OTHER, { record = { family = "personal" } })
local discovery = Moment("arrive", 600, 0.7, OTHER)
selected = Plates({ ordinary[1], ordinary[2], ordinary[3], ordinary[4], solo, discovery })
Check(Has(selected, ordinary[1]), "the first routine encounter remains represented")
Check(Has(selected, solo), "a solo event is not crowded out by repeated company")
Check(Has(selected, discovery), "a different observed place survives the same social family")
Eq(#Plates(ordinary), 3, "one family can fill the page when that is what happened")

local renewed = Moment("session", 800, 0.7, OTHER,
    { guid = "Player-0000-MEM00003", session = { id = 30 }, selection = { context = "return" } })
selected = Plates({ ordinary[1], ordinary[2], ordinary[3], solo, discovery, renewed })
Check(Has(selected, renewed), "a supported recurrence is not lost to a family quota")
local another = Moment("session", 900, 0.85, MAP,
    { guid = "Player-0000-MEM00004", session = { id = 40 } })
selected = Plates({ ordinary[1], ordinary[2], ordinary[3], another })
Check(Has(selected, another), "a different participant can distinguish the same kind of encounter")

local returns = {}
for i = 1, 4 do
    returns[i] = Moment("session", 100 + i, (i - 1) * 0.25 + 0.1, MAP,
        { guid = "Player-0000-MEM00001", session = { id = 200 + i }, selection = { context = "return" } })
end
selected = Plates({ returns[1], returns[2], returns[3], returns[4], solo, discovery })
Check(Has(selected, returns[1]), "the contextual return leads the choice")
Check(Has(selected, solo), "repeated contextual company cannot hide a solo milestone")
Check(Has(selected, discovery), "context does not turn one family into a monopoly")
Eq(#Plates(returns), 3, "contextual repetition still fills a page when there is nothing different")

--------------------------------------------------------------------------
Section("an occurrence counts once regardless of how many faces describe it")

local party, crowded = { id = 50 }, {}
for i = 1, 8 do
    crowded[#crowded + 1] = Moment("session", 500, 0.85, MAP,
        { guid = ("Player-0000-PARTY%03d"):format(i), session = party })
end
local one = Plates(crowded)
Eq(#one, 1, "the whole party shares its place")
Eq(one[1].selection.occurrences, 1, "eight participants establish one session")
for i = 1, 3 do
    crowded[#crowded + 1] = Moment("session", 100 + i, (i - 1) * 0.25 + 0.1, MAP,
        { guid = ("Player-0000-SINGLE%02d"):format(i), session = { id = 50 + i } })
end
selected = Plates(crowded)
Check(not Has(selected, crowded[1]), "party size does not displace an earlier equal encounter")

local note = { id = 70, text = "We stopped here." }
one = Plates({ Moment("note", 100, 0.1, MAP, { guid = "Player-0000-A", note = note }),
    Moment("note", 100, 0.1, MAP, { guid = "Player-0000-B", note = note }) })
Eq(one[1].selection.occurrences, 1, "a note naming two people is one authored occurrence")

local same = "observed-acquisition:71"
one = Plates({ Moment(probe, 100, 0.1, MAP, { record = { event = same, family = "item" } }),
    Moment(probe, 100, 0.1, MAP, { record = { event = same, family = "item" } }) })
Eq(one[1].selection.occurrences, 1, "feature-owned stable keys can join duplicate representations")

local spread, shared = {}, { id = 80 }
for i = 1, 3 do
    spread[i] = Moment("session", 100 + i, (i - 1) * 0.25 + 0.1, MAP,
        { guid = ("Player-0000-SPREAD%02d"):format(i), session = shared,
            selection = { context = "return" } })
end
local fresh = Moment("session", 700, 0.85, MAP,
    { guid = "Player-0000-NEW00001", session = { id = 81 } })
spread[#spread + 1] = fresh
Check(Has(Plates(spread), fresh), "different participant places of one session cannot hide a fresh occurrence")

--------------------------------------------------------------------------
Section("context comes from the declared evidence vocabulary")

for _, context in ipairs({ "linked", "first", "return", "repeated" }) do
    local m = Moment(probe, 100, 0.1, MAP, { record = { context = context } })
    Eq(R.Selection(m).context, context, "the registry recognises " .. context)
end
local unknown = Moment(probe, 100, 0.1, MAP, { record = { context = "very_memorable" } })
Eq(R.Selection(unknown).context, nil, "an unsupported claim earns no contextual priority")
Eq(R.Selection(unknown).family, probe, "a missing family falls back to the existing kind")
local fallback = Moment("stay", 100, 0.1, MAP, { selection = { context = "repeated" } })
Check(not Plates({ fallback })[1].selection.contextual, "a route fallback cannot promote itself through a label")
Eq(#Plates({}), 0, "nothing observed produces no forced highlight")
Eq(#Plates({ fallback }), 1, "a quiet recorded stop remains enough for a quiet page")

--------------------------------------------------------------------------
Section("equal facts give the same grouping and choice in a different order")

local simultaneous = {}
for i = 1, 6 do
    simultaneous[i] = Moment("session", 100, 0.1 + (i - 1) * 0.15, MAP,
        { guid = ("Player-0000-STABLE%02d"):format(i), session = { id = 100 + i } })
end
local expected = Signature(Plates(simultaneous))
for start = 1, #simultaneous do
    for _, direction in ipairs({ -1, 1 }) do
        local shuffled = {}
        for i = 0, #simultaneous - 1 do
            shuffled[#shuffled + 1] = simultaneous[((start - 1 + direction * i) % #simultaneous) + 1]
        end
        Eq(Signature(Plates(shuffled)), expected, "a rotated or reversed input has the same selected facts")
    end
end

--------------------------------------------------------------------------
Section("an observed change of outcome survives repeated fights")

do
    local route = J.Begin("Player-0000-FIGHTS01", 0, 10, MAP)
    local entry = { from = 0, to = 1000, fights = {} }
    for i = 1, 4 do
        entry.fights[i] = { t = i * 100, mapID = MAP, x = (i - 1) * 0.25 + 0.1, y = 0.5,
            guid = "Player-0000-OPPONENT", outcome = i == 4 and "lost" or "won" }
    end
    local moments = originalMoments(route, entry, {})
    Eq(R.Selection(moments[1]).family, "fight:won", "a measured win keeps its own outcome")
    Eq(R.Selection(moments[4]).family, "fight:lost", "a measured loss keeps its own outcome")
    Check(Has(Plates(moments), moments[4]), "three earlier wins do not erase the later loss")
    for i, mark in ipairs(entry.fights) do mark.outcome = i == 4 and "won" or "lost" end
    moments = originalMoments(route, entry, {})
    Check(Has(Plates(moments), moments[4]), "three earlier losses do not erase the later win")
    Eq(R.Selection(moments[4]).context, nil, "outcome order invents no linked recovery or revenge")
    entry.fights[4].outcome = nil
    moments = originalMoments(route, entry, {})
    Eq(R.Selection(moments[4]).family, "fight", "a missing historical outcome is never guessed")
    Eq(entry.fights[4].outcome, nil, "reading changes no source outcome")
end

--------------------------------------------------------------------------
Section("return context needs two explicit nearby encounters")

local me, guid = "Player-0000-OWNER001", "Player-0000-RETURN01"
local j = J.Begin(me, 100, 10, MAP)
j.segments = { { kind = "stop", from = 100, to = 1000, seconds = 900, mapID = MAP,
    x = 0.4, y = 0.5, r = 20, levelFrom = 10, levelTo = 10 } }
local previous = { id = 201, me = me, startedAt = 100, endedAt = 200,
    participants = { [guid] = { since = 100, last = 200, seconds = 100, near = { { 110, 190 } } } } }
local current = { id = 202, me = me, startedAt = 500, endedAt = 700,
    participants = { [guid] = { since = 500, last = 700, seconds = 200, near = { { 510, 690 } } } } }
local function SessionContext(sessions)
    local ctx = { me = me, sessions = sessions }
    local e = R.Gather(j, 500, 800, ctx)
    for _, m in ipairs(originalMoments(j, e, ctx)) do
        if m.kind == "session" and m.session == current then return R.Selection(m).context end
    end
end
Eq(SessionContext({ current, previous }), "return", "a completed earlier encounter establishes a return")
Eq(SessionContext({ previous, current }), "return", "the predicate is independent of session order")
Eq(SessionContext({ current }), nil, "one session cannot corroborate itself")
previous.endedAt = nil
Eq(SessionContext({ previous, current }), nil, "an unfinished previous session does not establish a separate encounter")
previous.endedAt = 600
Eq(SessionContext({ previous, current }), nil, "overlapping sessions are not a return")
previous.endedAt = 200
previous.participants[guid].near = {}
Eq(SessionContext({ previous, current }), nil, "remote group membership is not a previous nearby encounter")
previous.participants[guid].near = nil
Eq(SessionContext({ previous, current }), nil, "legacy missing proximity earns no new inference")
previous.participants[guid].near = { { 110, 190 } }
current.participants[guid].near = nil
Eq(SessionContext({ previous, current }), nil, "the current encounter also needs explicit proximity")
current.participants[guid].near = { { 510, 690 } }
previous.me = "Player-0000-OTHER001"
Eq(SessionContext({ previous, current }), nil, "another character's encounter is not this character's return")

--------------------------------------------------------------------------
Section("repeated setbacks are selected only within their observed scope")

j.segments[1].act = { deaths = 2 }
local function DeathContext(to)
    local e = R.Gather(j, 100, to, {})
    for _, m in ipairs(originalMoments(j, e, {})) do
        if m.kind == "death" then return R.Selection(m).context end
    end
end
Eq(DeathContext(1100), "repeated", "two recorded deaths distinguish the place")
Eq(DeathContext(800), nil, "a crossing aggregate does not lend future deaths to the page")
j.segments[1].act.deaths = 1
Eq(DeathContext(1100), nil, "one death is not repetition")

--------------------------------------------------------------------------
Section("only a reachable run page replaces its door")

local door = Moment("dungeon", 100, 0.4, MAP, { visit = { id = 400 } })
Eq(#Plates({ door }), 1, "a brief unqualified visit retains the only visible account of its door")
door.visit.bossesKilled = { "Briar Keeper" }
Check(R.RunWorthy(door.visit), "the fixture earns a run page")
Eq(#Plates({ door }), 0, "a qualified visit uses its run page instead of a duplicate door")
