-- Attributable help after a fight. The meter can name a source and the
-- recipient of a spell, but it gives neither a target GUID nor an action's
-- time. A remembered aggregate therefore cannot be split into encounters
-- just by subtracting its last total. This reader accepts only one new,
-- explicitly updated session, absent from the last readable idle baseline.
-- A session already allocated at combat-start must still have a readable
-- duration of at most two seconds. Reused sessions,
-- a missing baseline, a reset and overlapping fights are left unclaimed.
--
-- This file loads immediately before Capture.lua. Its values are transient;
-- Capture writes only flat, plain provenance and the observed contributions.
-- No health arithmetic, spell-target guess or combat-log access is involved.

local addonName, ns = ...
local Meter = {}
ns.Witnesses.Meter = Meter

local WAIT, TRIES, CLOCK_SLACK = 1, 5, 2
local TYPES = { heal = "HealingDone", absorb = "Absorbs", dispel = "Dispels" }
local active, pending, baseline, generation
generation = 0

local function Table(value)
    value = ns.Plain(value)
    return type(value) == "table" and value or nil
end

local function Number(value)
    value = ns.Plain(value)
    return type(value) == "number" and value == value and value < math.huge and value >= 0 and value or nil
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    return ok and Table(value) or nil
end

local function Catalog()
    local api = C_DamageMeter
    local sessions = api and Call(api.GetAvailableCombatSessions)
    if not sessions then return nil end
    local ids = {}
    for _, entry in ipairs(sessions) do
        entry = Table(entry)
        local id = entry and Number(entry.sessionID)
        if not id then return nil end
        ids[id] = entry and Number(entry.durationSeconds) or false
    end
    return ids
end

local function Out()
    return ns.Plain(UnitAffectingCombat("player")) == false
end

function Meter.Snapshot()
    if active or pending or not Out() then return end
    -- The first idle reading is a baseline only. A login/reload must not
    -- turn the latest old session into a newly observed encounter.
    baseline = Catalog()
end

function Meter.Cancel(f)
    if f and f.meter then f.meter.cancelled = true end
    if active == f then active = nil end
    if pending == f then pending = nil end
end

function Meter.Reset()
    Meter.Cancel(active)
    Meter.Cancel(pending)
    baseline = nil
    generation = generation + 1
end

function Meter.Start(f)
    Meter.Cancel(active)
    Meter.Cancel(pending)
    local atStart = Catalog()
    f.meter = { before = baseline, atStart = atStart, updated = {}, generation = generation,
        cancelled = baseline == nil or atStart == nil }
    baseline = nil
    active = f
end

-- Only literal recipient names are accepted. Forever's surname is part
-- of the name; dropping it, a realm, or every word after the first can
-- silently merge two people. Blank targets (seen in the client) stay blank.
local function Recipient(f, detail)
    return ns.Plain(detail.isPet) == false and ns.Plain(detail.isMob) == false
        and type(f.ownerName) == "string" and ns.Plain(detail.unitName) == f.ownerName
end

local function OwnerUnique(f)
    if f.ambiguousOwner or type(f.ownerName) ~= "string" or f.ownerName == "" then return false end
    for guid in pairs(f.people) do
        if ns.Characters.FullName(guid) == f.ownerName then return false end
    end
    return true
end

local function Details(spell)
    local details = Table(spell.combatSpellDetails)
    if not details then return nil end
    if ns.Plain(details.unitName) ~= nil or ns.Plain(details.amount) ~= nil then return { details } end
    return details
end

local function Contributions(f, id)
    local api = C_DamageMeter
    local kinds = Enum and Enum.DamageMeterType
    if not (api and kinds and api.GetCombatSessionFromID and api.GetCombatSessionSourceFromID) then return nil end
    if not OwnerUnique(f) then return false end
    local byAction = {}
    for action, kind in pairs(TYPES) do
        local which = ns.Plain(kinds[kind])
        if type(which) == "number" then
            local session = Call(api.GetCombatSessionFromID, id, which)
            local sources = session and Table(session.combatSources)
            if not sources then return nil end
            local duration = Number(session.durationSeconds)
            if duration and duration > math.max(0, f.ended - f.started) + CLOCK_SLACK then return false end
            byAction[action] = {}
            for _, source in ipairs(sources) do
                source = Table(source)
                if not source then return nil end
                local guid = ns.SafeGUID(source.sourceGUID)
                local creature = ns.Plain(source.sourceCreatureID)
                local knownCreature = type(creature) == "number" and creature > 0 and creature < math.huge
                    and creature == math.floor(creature)
                if action == "absorb" and (ns.IsSecret(source.sourceGUID) or ns.IsSecret(source.sourceCreatureID)
                    or (not guid and not knownCreature)) then return nil end
                -- A pet's contribution is not silently awarded to its
                -- owner. The actor was observed during this very fight.
                if guid and guid ~= ns.ownGUID and f.people[guid] and not f.people[guid].uncertain
                    and not ns.IsSecret(source.sourceCreatureID)
                    and (creature == nil or creature == 0) then
                    if byAction[action][guid] ~= nil then return false end
                    local data = Call(api.GetCombatSessionSourceFromID, id, which, guid, creature)
                    local spells = data and Table(data.combatSpells)
                    if not spells then return nil end
                    local spellsByID = {}
                    for _, spell in ipairs(spells) do
                        spell = Table(spell)
                        local details = spell and Details(spell)
                        if not details then return nil end
                        local spellID = Number(spell.spellID)
                        -- The native meter can merge a pet's spells into
                        -- a player source. Its creatureName is the marker;
                        -- a secret or absent marker is not an empty one.
                        local creatureName = ns.Plain(spell.creatureName)
                        local validID = spellID and spellID > 0 and spellID == math.floor(spellID)
                        if validID and creatureName == "" then
                            if spellsByID[spellID] ~= nil then return false end
                            local amount, matched = 0, false
                            for _, detail in ipairs(details) do
                                detail = Table(detail)
                                if not detail then return nil end
                                if Recipient(f, detail) then
                                    if matched then return false end
                                    matched = true
                                    -- A whole-spell total is never a
                                    -- fallback for this one recipient.
                                    local n = Number(detail.amount)
                                    if n then amount = n end
                                end
                            end
                            spellsByID[spellID] = amount
                        elseif action == "absorb" and (not validID or type(creatureName) ~= "string") then
                            -- Without a complete absorption spell set a
                            -- healing row may itself be a shield total.
                            return nil
                        end
                    end
                    byAction[action][guid] = spellsByID
                end
            end
        end
    end
    local result = {}
    for action, sources in pairs(byAction) do
        for guid, spells in pairs(sources) do
            local amount = 0
            local absorbs = byAction.absorb and byAction.absorb[guid] or {}
            for spellID, n in pairs(spells) do
                -- The public API does not promise disjoint healing and
                -- absorption categories. Preserve separate contributions;
                -- never report a shield again as a direct heal. A spell
                -- which does both conservatively keeps the shield only.
                if action ~= "heal" or (byAction.absorb and absorbs[spellID] == nil) then amount = amount + n end
            end
            if not Number(amount) then return false end
            if amount > 0 then
                result[guid] = result[guid] or {}
                result[guid][action] = amount
            end
        end
    end
    return result
end

local function Session(f)
    local state = f.meter
    local ids = Catalog()
    if not ids then return nil end
    local chosen
    for id in pairs(state.updated) do
        if state.before[id] == nil and ids[id] ~= nil then
            if chosen and chosen ~= id then return false end
            chosen = id
        end
    end
    if not chosen then return nil end
    if state.session and state.session ~= chosen then return false end
    -- Some clients allocate the new session before REGEN_DISABLED. That
    -- ordering is accepted only for a freshly started session absent from
    -- the idle baseline, with its update observed during this encounter.
    local startedDuration = state.atStart[chosen]
    if startedDuration ~= nil and (startedDuration == false or startedDuration > CLOCK_SLACK) then return false end
    state.session = chosen
    local duration = ids[chosen]
    if duration and duration > math.max(0, f.ended - f.started) + CLOCK_SLACK then return false end
    return chosen
end

function Meter.Finish(f, done)
    if active == f then active = nil end
    local state = f.meter
    if not state or state.cancelled then done(nil); Meter.Snapshot(); return end
    pending = f
    local attempts = 0
    local function Read()
        if state.cancelled or state.generation ~= generation or pending ~= f then done(nil); return end
        -- Healing after a resurrection belongs to the next life. An
        -- in-combat corpse may keep the API secret: it is not a zero.
        if f.death and ns.Plain(UnitIsDeadOrGhost("player")) ~= true then
            Meter.Cancel(f); done(nil); Meter.Snapshot(); return
        end
        attempts = attempts + 1
        local id = Out() and Session(f) or nil
        local values = type(id) == "number" and Contributions(f, id) or nil
        if values == false or id == false then
            Meter.Cancel(f); done(nil); Meter.Snapshot(); return
        end
        if values then
            pending = nil
            done(values, id)
            Meter.Snapshot()
        elseif attempts < TRIES then
            ns.After(WAIT, Read)
        else
            pending = nil
            done(nil)
            Meter.Snapshot()
        end
    end
    ns.After(WAIT, Read)
end

ns.On("DAMAGE_METER_COMBAT_SESSION_UPDATED", function(_, _, sessionID)
    sessionID = Number(sessionID)
    local f = active or pending
    if f and f.meter and sessionID then f.meter.updated[sessionID] = true
    elseif not f then Meter.Snapshot() end
end)

ns.On("DAMAGE_METER_CURRENT_SESSION_UPDATED", function() Meter.Snapshot() end)
ns.On("DAMAGE_METER_RESET", function() Meter.Reset(); Meter.Snapshot() end)
