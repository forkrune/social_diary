-- Attributed interventions and continuous witnessing, driven through the
-- same public events as the client. All names and GUIDs are synthetic.
local T = ...
local mock, F, Eq, Check, Section = T.mock, T.F, T.Eq, T.Check, T.Section
local ns = T.Boot()
local W = ns.Witnesses
local SELF, FRIEND, STRANGER = F.SELF, F.FRIEND, F.STRANGER
local FOE = "Creature-0-4615-1-832-2955-00004B69A3"
local OTHER = "Creature-0-4615-1-832-2955-00004B69A4"
local catalog, data, reads = {}, {}, 0
local HEAL, ABSORB, DISPEL = 2, 4, 6
Enum.DamageMeterType = { HealingDone = HEAL, Absorbs = ABSORB, Dispels = DISPEL, DamageTaken = 7, Deaths = 9 }
Enum.DamageMeterSessionType = { Current = 1 }
_G.C_DamageMeter = {
    GetAvailableCombatSessions = function()
        local list = {}
        for id, duration in pairs(catalog) do list[#list + 1] = { sessionID = id, durationSeconds = duration } end
        return list
    end,
    GetCombatSessionFromID = function(id, kind)
        reads = reads + 1
        if mock.inCombat then return mock.secret({}) end
        local sources = {}
        for guid, actor in pairs(data[id] and data[id][kind] or {}) do
            sources[#sources + 1] = { sourceGUID = guid, sourceCreatureID = actor.creature,
                isLocalPlayer = guid == SELF.guid, totalAmount = 50 }
        end
        return { combatSources = sources, durationSeconds = catalog[id] }
    end,
    GetCombatSessionSourceFromID = function(id, kind, guid)
        if mock.inCombat then return mock.secret({}) end
        local actor = data[id] and data[id][kind] and data[id][kind][guid]
        return { combatSpells = actor and actor.spells or {} }
    end,
}

_G.GetTime = function() return mock.now end
_G.UnitAffectingCombat = function(unit)
    if unit == "player" then return mock.inCombat end
    local def = mock.units[unit]
    if def and def.combat ~= nil then return def.combat end
    return false
end
_G.UnitIsDeadOrGhost = function(unit)
    if unit == "player" then return mock.dead or mock.ghost end
    local def = mock.units[unit]
    if def and def.dead ~= nil then return def.dead end
    return false
end
_G.UnitIsAFK = function(unit)
    local def = mock.units[unit]
    if def and def.afk ~= nil then return def.afk end
    return false
end

local function Copy(def, extra)
    local result = {}
    for k, v in pairs(def) do result[k] = v end
    for k, v in pairs(extra or {}) do result[k] = v end
    return result
end

local function Fresh()
    mock.timers = {}
    T.BlankDiary()
    ns.Roster.Update({}, true, false)
    mock.ClearUnits()
    mock.SetUnit("player", SELF)
    mock.inCombat, mock.dead, mock.ghost, mock.feigning = false, false, false, false
    mock.now = mock.now + 100
    catalog, data, reads = { [10] = 40 }, {}, 0
    ns.Fire("SD_DIARY_CHANGED")
end

local function Actor(def, extra, target)
    mock.SetUnit("nameplate1", Copy(def, extra))
    mock.SetUnit("nameplate1target", target)
    mock.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
end

local function Threat(guid, extra)
    mock.SetUnit("target", Copy({ guid = guid or FOE, name = { "Plainstrider" }, isPlayer = false,
        hostile = true, combat = true }, extra))
    mock.SetUnit("targettarget", SELF)
    mock.fire("PLAYER_TARGET_CHANGED")
end

local function Start()
    mock.inCombat = true
    mock.fire("PLAYER_REGEN_DISABLED")
end

local function Pass(n)
    for _ = 1, n do mock.now = mock.now + 1; ns._test.WitnessesScan() end
end

local function Flush()
    for _ = 1, 8 do mock.RunTimers() end
end

local function End()
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    Flush()
end

local function Die()
    mock.dead = true
    mock.fire("PLAYER_DEAD")
    mock.inCombat = false
    mock.fire("PLAYER_REGEN_ENABLED")
    Flush()
end

local function Row(guid, kind) return ns._test.LatestInteraction(guid or FRIEND.guid, kind or W.AID) end
local function Count(guid) return #(ns.Interactions.For(guid or FRIEND.guid) or {}) end

local function Spell(kind, amount, opts)
    opts = opts or {}
    local id, guid = opts.session or 11, opts.guid or FRIEND.guid
    data[id] = data[id] or {}
    data[id][kind] = data[id][kind] or {}
    local actor = data[id][kind][guid] or { spells = {}, creature = opts.sourceCreature }
    data[id][kind][guid] = actor
    local detail = { unitName = opts.target or SELF.name[1], isPet = false, isMob = false, amount = amount }
    for k, v in pairs(opts.detail or {}) do detail[k] = v end
    actor.spells[#actor.spells + 1] = { spellID = opts.spell or (1000 + kind), creatureName = opts.pet or "",
        totalAmount = opts.total or amount, combatSpellDetails = opts.details or detail }
    return actor.spells[#actor.spells]
end

local function Session(id, duration)
    catalog[id or 11] = duration or 3
    mock.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", HEAL, id or 11)
end

Section("a group member's actual kill of an observed threat")
Fresh()
ns.Roster.Update({ [FRIEND.guid] = {} }, true, false)
Actor(FRIEND, { combat = true })
Start(); Threat(); Pass(2)
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
End()
local row = Row()
Check(row, "the attributed group intervention was lost")
Eq(row.context.evidence, 1, "provenance")
Eq(row.context.method, "party_kill", "kill method")
Eq(row.context.kills, 1, "duplicate kill counted")
Eq(row.context.npcID, 2955, "attributed creature")
Eq(row.context.grouped, true, "observed group status")
Eq(T.Rows(FRIEND.guid, W.SAVED), 0, "survival became an unmeasured rescue")

Section("the same attributable action before a real death")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(); Pass(2)
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
Die()
row = Row(FRIEND.guid, W.HELPED)
Check(row, "fatal assistance was lost")
Eq(row.context.pct, nil, "invented remaining health")

Section("targeting and unrelated combat cannot establish help")
Fresh(); Actor(FRIEND, {}, Copy({ guid = FOE, name = { "Plainstrider" }, isPlayer = false }))
Start(); Threat(); Pass(2)
mock.units.nameplate1.combat = true
mock.SetUnit("nameplate1target", nil)
Pass(2); mock.fire("UNIT_DIED", FOE); Die()
Eq(Count(), 0, "target/combat coincidence became assistance")

Section("precise victim, actor and creature-combat gates")
for _, bad in ipairs({ "different", "self", "pet", "idle", "hostile", "secret", "unseen", "afterdeath" }) do
    Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(nil, bad == "idle" and { combat = false } or nil); Pass(2)
    local actor, victim = FRIEND.guid, FOE
    if bad == "different" then victim = OTHER end
    if bad == "self" then actor = SELF.guid end
    if bad == "pet" then actor = "Pet-0-4615-1-832-123-00004B69A3" end
    if bad == "hostile" then mock.units.nameplate1.hostile = true end
    if bad == "secret" then actor = mock.secret(actor) end
    if bad == "unseen" then mock.SetUnit("nameplate1", nil) end
    if bad == "afterdeath" then mock.dead = true; mock.fire("PLAYER_DEAD") end
    mock.fire("PARTY_KILL", actor, victim)
    End()
    Eq(Count(), 0, "bad kill accepted: " .. bad)
end

Section("continuous pre-death observation includes a fall")
Fresh(); Actor(STRANGER, {}, SELF); Pass(2); Die()
row = Row(STRANGER.guid, W.WATCHED)
Check(row, "ambient witness was lost")
Eq(row.context.method, "target_streak", "witness method")
Eq(row.context.watched, 2, "sampled interval")
Eq(row.context.name, nil, "fall acquired a targeted creature cause")

Section("first-at-death, stale, invisible and unknown observations stay unclaimed")
for _, bad in ipairs({ "first", "stale", "broken", "hidden", "afk", "secretcombat", "secretdead", "secretafk", "removed" }) do
    Fresh(); Start()
    if bad ~= "first" then Actor(STRANGER, {}, SELF); Pass(2) end
    if bad == "first" then Actor(STRANGER, {}, SELF) end
    if bad == "stale" then mock.now = mock.now + 5 end
    if bad == "broken" then mock.SetUnit("nameplate1target", nil); ns._test.WitnessesScan() end
    if bad == "hidden" then mock.units.nameplate1.visible = false end
    if bad == "afk" then mock.units.nameplate1.afk = true end
    if bad == "secretcombat" then mock.units.nameplate1.combat = mock.secret(false) end
    if bad == "secretdead" then mock.units.nameplate1.dead = mock.secret(false) end
    if bad == "secretafk" then mock.units.nameplate1.afk = mock.secret(false) end
    if bad == "removed" then mock.SetUnit("nameplate1", nil) end
    Die()
    Eq(Count(STRANGER.guid), 0, "bad witness accepted: " .. bad)
end

Section("actual recipient-specific healing, absorption and dispelling")
for _, kind in ipairs({ HEAL, ABSORB, DISPEL }) do
    Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session()
    Spell(kind, 30)
    End()
    row = Row()
    Check(row, "direct aid missing for meter kind " .. kind)
    Eq(row.context.method, "meter", "meter provenance")
    Eq(row.context.meterSession, 11, "explicit meter session")
    Eq(row.context.amount, 30, "recipient amount")
    Eq(row.context.pct, nil, "meter aid acquired health")
end

Section("new session allocated just before combat-start event")
Fresh(); Actor(FRIEND, { combat = true }); catalog[11] = 0; Start(); Pass(3); Session()
Spell(HEAL, 30); End()
Check(Row(), "new session allocated before REGEN was rejected")

Section("one row retains all contributions without double-counting shields as healing")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(); Pass(3); Session()
Spell(HEAL, 30, { spell = 100 }); Spell(ABSORB, 30, { spell = 100 }); Spell(DISPEL, 1)
mock.fire("PARTY_KILL", FRIEND.guid, FOE); End()
row = Row()
Check(row, "combined aid missing")
Eq(Count(), 1, "one encounter produced multiple rows")
Eq(row.context.action, "absorb", "shield total was called a heal")
Eq(row.context.healed, nil, "absorption counted as healing")
Eq(row.context.absorbed, 30, "absorption lost")
Eq(row.context.dispelled, 1, "dispel lost")
Eq(row.context.kills, 1, "kill lost")

Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session()
Spell(HEAL, 20, { spell = 101 }); Spell(ABSORB, 30, { spell = 100 }); End()
row = Row()
Eq(row.context.action, "heal", "separate heal priority")
Eq(row.context.healed, 20, "separate heal lost")
Eq(row.context.absorbed, 30, "separate shield lost")

Section("recipient identity, pet ownership and amount ambiguity fail closed")
for _, bad in ipairs({ "blank", "other", "firstname", "zero", "secretamount", "pettarget", "mobtarget", "petspell",
    "secretpetspell", "petsource", "secretsource", "unknownactor", "duplicate", "collision" }) do
    Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session()
    local opts, amount = {}, 30
    if bad == "blank" then opts.target = "" end
    if bad == "other" then opts.target = "Other Person" end
    if bad == "firstname" then opts.target = SELF.name[1]:match("^%S+") end
    if bad == "zero" then amount, opts.total = 0, 100 end
    if bad == "secretamount" then amount, opts.total = mock.secret(30), 100 end
    if bad == "pettarget" then opts.detail = { isPet = true } end
    if bad == "mobtarget" then opts.detail = { isMob = true } end
    if bad == "petspell" then opts.pet = "A summoned pet" end
    if bad == "secretpetspell" then opts.pet = mock.secret("") end
    if bad == "petsource" then opts.sourceCreature = 123 end
    if bad == "secretsource" then opts.sourceCreature = mock.secret(0) end
    if bad == "unknownactor" then opts.guid = STRANGER.guid end
    if bad == "collision" then
        local record = ns.Characters.Get(FRIEND.guid)
        local name = record.names[#record.names]
        name.first, name.surname = ns.NameFromUnit("player")
    end
    Spell(HEAL, amount, opts)
    if bad == "duplicate" then Spell(HEAL, 30, opts) end
    End()
    Eq(Count(), 0, "ambiguous meter aid accepted: " .. bad)
end

Section("same-session old totals, missing baseline, reset and overlap are not new help")
for _, bad in ipairs({ "reused", "noevent", "oldnew", "reset", "overlap", "resurrect", "forget", "forgetall", "world", "baseline" }) do
    Fresh(); Actor(FRIEND, { combat = true });
    if bad == "oldnew" then catalog[11] = 40 end
    if bad == "baseline" then mock.inCombat = true; ns.Fire("SD_DIARY_CHANGED") end
    Start(); Pass(3)
    if bad == "reused" then Session(10); Spell(HEAL, 30, { session = 10 })
    else Session(); Spell(HEAL, 30) end
    if bad == "noevent" then
        -- A second session, not the one whose update was observed, cannot
        -- be selected merely because it has the highest ID.
        data[11], catalog[11] = nil, nil
        catalog[12] = 3; Spell(HEAL, 30, { session = 12 })
    end
    if bad == "reset" then mock.fire("DAMAGE_METER_RESET") end
    if bad == "resurrect" then mock.dead = true; mock.fire("PLAYER_DEAD") end
    mock.inCombat = false; mock.fire("PLAYER_REGEN_ENABLED")
    if bad == "overlap" then mock.inCombat = true; mock.fire("PLAYER_REGEN_DISABLED") end
    if bad == "resurrect" then mock.dead = false; mock.fire("PLAYER_ALIVE") end
    if bad == "forget" then ns.Characters.Forget(FRIEND.guid) end
    if bad == "forgetall" then ns.ForgetEverywhere(nil) end
    if bad == "world" then mock.fire("PLAYER_ENTERING_WORLD") end
    Flush()
    Eq(Count(), 0, "unbound meter aid accepted: " .. bad)
end

Section("healing cannot be separated from shields without readable absorption evidence")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session()
Spell(HEAL, 30)
Enum.DamageMeterType.Absorbs = nil
End()
Eq(Count(), 0, "missing absorption capability became pure healing")
Enum.DamageMeterType.Absorbs = ABSORB

for _, bad in ipairs({ "source", "spell", "petmarker" }) do
    Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session()
    Spell(HEAL, 30, { spell = 100 })
    if bad == "source" then Spell(ABSORB, 30, { guid = "unknown", sourceCreature = 0, spell = 100 }) end
    if bad == "spell" then Spell(ABSORB, 30, { spell = 0 }) end
    if bad == "petmarker" then Spell(ABSORB, 30, { spell = 100, pet = 123 }) end
    End()
    Eq(Count(), 0, "incomplete absorption identity became pure healing: " .. bad)
end

Section("forgetting during combat cannot replay pre-forget assistance on a later scan")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session(); Spell(HEAL, 30)
ns.Characters.Forget(FRIEND.guid)
Pass(1)
End()
Eq(Count(), 0, "forgotten actor was reacquired for the old encounter's meter total")

Section("ineligible or distant namesakes still make recipient identity ambiguous")
for _, status in ipairs({ "afk", "hidden" }) do
    Fresh(); Actor(FRIEND, { combat = true }); Start(); Pass(3); Session(); Spell(HEAL, 30)
    mock.SetUnit("party1", Copy(STRANGER, { name = SELF.name, afk = status == "afk", visible = status ~= "hidden" }))
    ns._test.WitnessesScan()
    End()
    Eq(Count(), 0, "an ineligible namesake was ignored: " .. status)
end

Section("a corpse observed at combat-end belongs to the same fatal encounter")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(); Pass(2)
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
mock.inCombat, mock.dead = false, true
mock.fire("PLAYER_REGEN_ENABLED")
mock.now = mock.now + 1
mock.fire("PLAYER_DEAD"); Flush()
row = Row(FRIEND.guid, W.HELPED)
Check(row, "death-before-regeneration ordering lost the actual assistance")
Eq(row.context.ended, mock.now, "fatal evidence did not bind to the death's time")

Section("a late fall does not turn a survived intervention into failed rescue")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(); Pass(2)
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
mock.inCombat = false; mock.fire("PLAYER_REGEN_ENABLED")
mock.now = mock.now + 2
mock.dead = true; mock.fire("PLAYER_DEAD"); Flush()
Eq(T.Rows(FRIEND.guid, W.AID), 1, "survived aid was lost")
Eq(T.Rows(FRIEND.guid, W.HELPED), 0, "unrelated fall borrowed previous helpers")

Section("duels and duplicate combat-start events")
Fresh(); Actor(FRIEND, { combat = true }); Start(); Threat(); Pass(2)
local fight = ns._test.Witnesses()
mock.fire("PLAYER_REGEN_DISABLED")
Eq(ns._test.Witnesses(), fight, "duplicate start replaced the fight")
mock.fire("PARTY_KILL", FRIEND.guid, FOE)
ns.Fire("SD_DUEL_FINISHED"); End()
Eq(Count(), 0, "duel became rescue or assistance")
