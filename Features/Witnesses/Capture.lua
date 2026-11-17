-- Witnesses' capture. A target selection is not an attack, an intention,
-- or a rescue. A death witness requires a continuous, readable targeting
-- streak which existed before the death and is still present at it. Help
-- requires an attributed kill of an observed threat, or Meter.lua's
-- recipient-specific healing, absorption or dispel in one new encounter.
--
-- The target game hides health and the combat log. Nothing here derives
-- health from aggregate damage, promotes survival into a rescue, or awards
-- an unclaimed kill to whoever happened to have a creature targeted.
--
-- This file stays after Capture/ in the TOC. Nearby's reunion snapshot is
-- therefore taken before a witness first observes a character. The meter
-- helper is loaded directly before this file; the feature owns all these
-- listeners and writes no new core event or schema.

local addonName, ns = ...
local Witnesses = ns.Witnesses
local Meter = Witnesses.Meter
local WAIT = { scan = 1, gap = Witnesses.WATCHING.gap, death = 5, settle = 5 }
local POINTED = { "target", "focus", "mouseover" }
local POINT = { target = true, focus = true, mouseover = true }
local fights, ambient, ticker = {}, nil, nil
local KEEP = 3

local function Clock() return GetTime and GetTime() or ns.Now() end

local function Flag(fn, unit)
    if type(fn) ~= "function" then return nil end
    return ns.Plain(fn(unit))
end

local function Visible(unit)
    return ns.Plain(UnitExists(unit)) == true
        and (not UnitIsVisible or ns.Plain(UnitIsVisible(unit)) == true)
end

local function Current()
    local f = fights[#fights]
    return f and not f.ended and not f.death and not f.cancelled and f or nil
end

local function NewFight(ambientOnly)
    local first, surname = ns.NameFromUnit("player")
    return { started = ns.Now(), clock = Clock(), foes = {}, people = {}, streak = {},
        aids = {}, killed = {}, forgotten = {}, ambient = ambientOnly, ownerName = ns.JoinName(first, surname) }
end

local function Ambient()
    if not ambient then ambient = NewFight(true) end
    return ambient
end

local function Trace(message, ...)
    if not ns.DebugOn() then return end
    if select("#", ...) > 0 then message = message:format(...) end
    ns.Debug("witnesses: %s", message)
    local log = ns.db.witnessTrace
    if type(log) ~= "table" then log = {}; ns.db.witnessTrace = log end
    log[#log + 1] = date("%H:%M:%S", ns.Now()) .. " " .. message
    while #log > 600 do table.remove(log, 1) end
end

local function Each(fn)
    for _, unit in ipairs(POINTED) do fn(unit) end
    for _, unit in ipairs(ns.Units.Plates) do fn(unit) end
    for _, unit in ipairs(ns.Units.Group()) do fn(unit) end
end

-- An exact creature GUID, observed in combat with the player targeted.
-- Clicking a hostile creature, or seeing one idle nearby, is not enough.
local function Creature(f, unit)
    if f.ambient or not Visible(unit) then return end
    local guid = ns.Plain(UnitGUID(unit))
    local npcID = ns.NpcID(guid)
    if not npcID or ns.Plain(UnitCanAttack("player", unit)) ~= true
        or Flag(UnitAffectingCombat, unit) ~= true or Flag(UnitIsDeadOrGhost, unit) ~= false
        or ns.Plain(UnitGUID(unit .. "target")) ~= ns.ownGUID then return end
    local name = ns.Plain((UnitName(unit)))
    local rank = UnitClassification and ns.Plain(UnitClassification(unit))
    f.foes[guid] = { npcID = npcID, name = type(name) == "string" and name or nil,
        rank = type(rank) == "string" and rank ~= "normal" and rank or nil, last = Clock() }
    f.liveFoes[guid] = true
end

local function Person(f, unit, seen)
    if ns.Plain(UnitExists(unit)) ~= true then return end
    local guid = ns.SafeGUID(UnitGUID(unit))
    if not guid or guid == ns.ownGUID then return end
    -- Identity ambiguity is useful even when this person is not an
    -- eligible helper: an AFK, dead or distant namesake may have been a
    -- meter spell's recipient earlier in this same encounter.
    local first, surname = ns.NameFromUnit(unit)
    if f.ownerName and ns.JoinName(first, surname) == f.ownerName then f.ambiguousOwner = true end
    if not Visible(unit) or f.forgotten[guid] then return end
    if seen then seen[guid] = true end
    local streak = f.streak[guid]
    local fighting, dead, afk = Flag(UnitAffectingCombat, unit), Flag(UnitIsDeadOrGhost, unit), Flag(UnitIsAFK, unit)
    -- Unknown is not false. In particular a restricted AFK/combat value
    -- must not create the appearance of an idle, deliberate spectator.
    if ns.Plain(UnitCanAttack("player", unit)) ~= false or dead ~= false or afk ~= false
        or (fighting ~= true and fighting ~= false) then
        if streak then streak.broken = true end
        if f.people[guid] then f.people[guid].uncertain = true end
        return
    end
    local now = Clock()
    local target = ns.Plain(UnitGUID(unit .. "target"))
    if f.ambient and target ~= ns.ownGUID then
        if streak then streak.broken = true end
        return
    end
    local person = f.people[guid]
    if not person then
        local record = ns.Characters.ObserveUnit(unit)
        if not record then return end
        person = { record = record }
        f.people[guid] = person
    end
    person.last, person.unit = now, unit
    person.grouped = ns.Roster.Has(guid) == true
    local session = ns.Sessions.Current()
    person.session = session and session.participants[guid] and session.id or nil
    local looking = fighting == false and not ns.Roster.Has(guid)
        and (target == ns.ownGUID or f.liveFoes[target] == true)
    if not looking then
        if streak then streak.broken = true end
        return
    end
    if not streak or streak.broken or now - streak.last > WAIT.gap or now < streak.last then
        streak = { from = now, last = now, samples = 1, target = target }
        f.streak[guid] = streak
    elseif now > streak.last then
        streak.last, streak.samples, streak.target = now, streak.samples + 1, target
    end
end

local function ReadAll(f)
    -- First find threats so a person's position in the token list cannot
    -- decide whether their target is recognised as part of this fight.
    f.liveFoes = {}
    Each(function(unit) Creature(f, unit); Creature(f, unit .. "target") end)
    local seen = {}
    Each(function(unit) Person(f, unit, seen) end)
    for guid, streak in pairs(f.streak) do
        if not seen[guid] then streak.broken = true end
    end
end

local function StillKnown(f, guid)
    local person = f.people[guid]
    return person and ns.Characters.Get(guid) == person.record
end

local PRIORITY = { "heal", "absorb", "dispel", "kill" }
local COUNTERS = { heal = "healed", absorb = "absorbed", dispel = "dispelled", kill = "kills" }

local function Aid(f, guid)
    if not f.aids[guid] then f.aids[guid] = {} end
    return f.aids[guid]
end

local function Write(f, guid, kind, context)
    if f.cancelled or not StillKnown(f, guid) then return end
    context.evidence, context.started, context.ended = 1, f.started, f.death or f.ended
    local person = f.people[guid]
    context.grouped = person.grouped or nil
    ns.Interactions.Add(guid, kind, { time = f.death or f.ended, where = f.where, context = context,
        session = person.session or false })
    Trace("%s: %s (%s)", kind, ns.Characters.FullName(guid) or guid, context.method)
end

local function Finalize(f)
    if f.finalized or f.cancelled then return end
    f.finalized = true
    for guid, aid in pairs(f.aids) do
        local context = {}
        for _, action in ipairs(PRIORITY) do
            local amount = aid[action]
            if amount and amount > 0 then
                context[COUNTERS[action]] = amount
                if not context.action then context.action, context.amount = action, amount end
            end
        end
        if context.action then
            context.method = context.action == "kill" and "party_kill" or "meter"
            context.meterSession = aid.meterSession
            -- One attributed creature only. A single card must not name
            -- whichever of several foes happened to be targeted last.
            if context.action == "kill" and aid.foe and not aid.many then
                context.npcID, context.name, context.rank = aid.foe.npcID, aid.foe.name, aid.foe.rank
            end
            Write(f, guid, f.death and Witnesses.HELPED or Witnesses.AID, context)
        end
    end
    for guid, watched in pairs(f.witnesses or {}) do
        if not f.aids[guid] then
            Write(f, guid, Witnesses.WATCHED, { method = "target_streak", action = "witness",
                watched = watched, subZone = f.where and f.where.subZone })
        end
    end
end

local function Finish(f)
    if f.finishing or f.cancelled then return end
    f.finishing = true
    f.ended = f.ended or f.death or ns.Now()
    f.where = f.where or ns.Where()
    if f.ambient then Finalize(f); return end
    Meter.Finish(f, function(values, sessionID)
        if f.cancelled or f.finalized then return end
        for guid, valuesForPerson in pairs(values or {}) do
            if StillKnown(f, guid) then
                local aid = Aid(f, guid)
                for action, amount in pairs(valuesForPerson) do aid[action] = amount end
                aid.meterSession = sessionID
            end
        end
        f.meterDone = true
        if f.death or f.settled then Finalize(f) end
    end)
    -- PLAYER_REGEN_ENABLED can precede PLAYER_DEAD. Give that ordering
    -- its existing leeway before deciding whether the encounter survived.
    ns.After(WAIT.settle, function()
        f.settled = true
        if f.meterDone then Finalize(f) end
    end)
end

local function Scan()
    if ns.InBattleground() or Flag(UnitIsDeadOrGhost, "player") ~= false then return end
    local f = Current() or Ambient()
    ReadAll(f)
    if f.ambient then
        local any = false
        for _, streak in pairs(f.streak) do if not streak.broken then any = true; break end end
        if not any and ticker then ticker.Cancel(); ticker = nil; ambient = nil end
    end
end

local function Tick()
    if not ticker then ticker = ns.Every(WAIT.scan, Scan) end
end

local function Observe()
    if ns.InBattleground() or Flag(UnitIsDeadOrGhost, "player") ~= false then return end
    local f = Current() or Ambient()
    ReadAll(f)
    for _, streak in pairs(f.streak) do if not streak.broken then Tick(); return end end
    if f.ambient then ambient = nil end
end

local function Died()
    if ns.InBattleground() or ns.Feigning("player") or (ns.Duelling and ns.Duelling()) then return end
    local now, at = ns.Now(), Clock()
    local f = fights[#fights]
    if not f or f.finalized or f.cancelled
        or (f.ended and (not f.endedDead or now - f.ended > WAIT.death)) then f = ambient end
    if not f or f.death then return end
    -- Capture the pre-death streak first. ReadAll at the death may
    -- corroborate it, but can never turn a first look into a witness.
    local before = {}
    for guid, streak in pairs(f.streak) do
        if not streak.broken and streak.samples >= 2 and streak.from < at and at - streak.last <= WAIT.gap then
            before[guid] = { from = streak.from, last = streak.last }
        end
    end
    ReadAll(f)
    f.witnesses = {}
    for guid, previous in pairs(before) do
        local streak = f.streak[guid]
        if streak and not streak.broken and streak.from == previous.from and streak.last == at then
            f.witnesses[guid] = math.floor((at - previous.from) * 10 + 0.5) / 10
        end
    end
    f.death, f.where = now, ns.Where()
    if ticker then ticker.Cancel(); ticker = nil end
    ambient = nil
    Finish(f)
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if Current() or ns.InBattleground() or Flag(UnitIsDeadOrGhost, "player") ~= false
        or (ns.Duelling and ns.Duelling()) then return end
    local previous = fights[#fights]
    if previous and previous.finishing and not previous.finalized then
        Meter.Cancel(previous)
        Finalize(previous)
    end
    local f = NewFight()
    fights[#fights + 1] = f
    while #fights > KEEP do table.remove(fights, 1) end
    ambient = nil
    Meter.Start(f)
    ReadAll(f)
    Tick()
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    local f = Current()
    if f then
        ReadAll(f)
        f.ended, f.where = ns.Now(), ns.Where()
        f.endedDead = Flag(UnitIsDeadOrGhost, "player") == true
        if ns.Duelling and ns.Duelling() then f.cancelled = true; Meter.Cancel(f) end
        Finish(f)
    elseif not fights[#fights] then Meter.Snapshot() end
    if ticker then ticker.Cancel(); ticker = nil end
    Observe()
end)

ns.On("PARTY_KILL", function(_, attacker, victim)
    local f = Current()
    attacker, victim = ns.SafeGUID(attacker), ns.Plain(victim)
    if not f or not attacker or attacker == ns.ownGUID or type(victim) ~= "string" or f.killed[victim] then return end
    local foe, person = f.foes[victim], f.people[attacker]
    if not foe or not person or Clock() - person.last > WAIT.gap or not StillKnown(f, attacker) then return end
    -- A known actor must still be this friendly, living player, rather
    -- than a recycled nameplate or a character observed before a duel.
    local unit = person.unit
    if not Visible(unit) or ns.SafeGUID(UnitGUID(unit)) ~= attacker
        or ns.Plain(UnitCanAttack("player", unit)) ~= false
        or Flag(UnitIsDeadOrGhost, unit) ~= false or Flag(UnitIsAFK, unit) ~= false then return end
    f.killed[victim] = true
    local aid = Aid(f, attacker)
    aid.kill = (aid.kill or 0) + 1
    if aid.victim and aid.victim ~= victim then aid.many = true end
    aid.victim, aid.foe = victim, foe
end)

ns.On("PLAYER_DEAD", Died)
ns.On("SD_DUEL_FINISHED", function()
    local f = fights[#fights]
    if f and not f.finalized then f.cancelled = true; Meter.Cancel(f) end
    ambient = nil
end)
ns.On("PLAYER_TARGET_CHANGED", Observe)
ns.On("PLAYER_FOCUS_CHANGED", Observe)
ns.On("UPDATE_MOUSEOVER_UNIT", Observe)
ns.On("NAME_PLATE_UNIT_ADDED", Observe)
ns.On("NAME_PLATE_UNIT_REMOVED", Observe)
ns.On("GROUP_ROSTER_UPDATE", Observe)
ns.On("UNIT_TARGET", function(_, unit)
    unit = ns.Plain(unit)
    if type(unit) == "string" and (POINT[unit] or unit:match("^nameplate%d+$")
        or unit:match("^party%d+$") or unit:match("^raid%d+$")) then Observe() end
end)

local function Reset()
    for _, f in ipairs(fights) do f.cancelled = true; Meter.Cancel(f) end
    fights, ambient = {}, nil
    if ticker then ticker.Cancel(); ticker = nil end
    Meter.Reset()
    Meter.Snapshot()
end

ns.On("PLAYER_ENTERING_WORLD", Reset)
ns.On("PLAYER_LEAVING_WORLD", Reset)
ns.On("SD_DIARY_CHANGED", Reset)
ns.On("PLAYER_ALIVE", function()
    for _, f in ipairs(fights) do if f.death then Meter.Cancel(f); Finalize(f) end end
    Meter.Snapshot()
end)
ns.On("PLAYER_UNGHOST", function()
    for _, f in ipairs(fights) do if f.death then Meter.Cancel(f); Finalize(f) end end
    Meter.Snapshot()
end)

-- Deferred meter work is a store too: forgetting a person removes the
-- pending evidence immediately, even when the caller does not fire a UI
-- refresh. It cannot later put their row or character back in the diary.
ns.RegisterStore("witnesses", function(guid)
    local function Forget(f)
        if not f then return end
        if guid == nil then
            f.cancelled = true
            Meter.Cancel(f)
        else
            f.forgotten[guid] = true
            f.people[guid], f.streak[guid], f.aids[guid] = nil, nil, nil
            if f.witnesses then f.witnesses[guid] = nil end
        end
    end
    for _, f in ipairs(fights) do Forget(f) end
    Forget(ambient)
    if guid == nil then
        fights, ambient = {}, nil
        if ticker then ticker.Cancel(); ticker = nil end
        Meter.Reset()
    end
end)

-- The old close-call message has no attributable action or measured
-- health. Kept as a no-op for callers; automatic rescue rows are retired.
function Witnesses.Survived() end

function ns._test.Witnesses() return fights[#fights] or ambient end
ns._test.WitnessesScan = Scan
