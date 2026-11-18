-- Profession caps (JRN-29): a profession's skill as far as it can go, read
-- off the client as it changes.
--
-- Forever has the modern profession API, not the classic skill lines
-- (probe 12 Oct: GetNumSkillLines is nil; GetProfessionInfo gives "First
-- Aid", 1, 75, 129). Each change reads every profession and holds it
-- against the last reading, by the profession's id; the first reading
-- after the diary was not watching only sets the mark, as the bags' does
-- (Features/Firsts/Capture.lua). CHAT_MSG_SKILL's words can be secret, so
-- it is a cue to read and never read itself; a burst of skill-ups (a
-- mining run) is one reading.
--
-- Watching is the route's: a cap is kept only while the route is
-- (ns.Journey.Kept: "Keep my own route" on, the logged-in character's own
-- route and not /sd testdata's). While it is not, nothing is held, so a
-- cap reached meanwhile is not one. The first reading after entering the
-- world waits for SD_WORLD_SETTLED (Core/Events.lua), the moment the bags
-- are read for the firsts, when the client has the professions loaded.
-- A cap reached goes on the route (ProfessionCaps.Add, Kind.lua). Other
-- positive readings go to skillProgress. They establish only that a
-- skill rose: no client signal here says what was crafted or gathered.
-- The capture runs in the existing features block. Its client events
-- share no mutable state with the other listeners; SD_WORLD_SETTLED is
-- still the baseline hand-off from Capture/Journey.lua.

local addonName, ns = ...

local ProfessionCaps = ns.ProfessionCaps

local SKILLS = {
    settle = 1,    -- seconds a burst of skill changes is gathered into one reading
}

-- The last reading, { [skillLine] = { rank, max, name } }; nil while there
-- is none since the diary last watched.
local skills, source, readAt
local skillsDue = false
local settled = false
local generation = 0
local progress = {}

-- A queued reading from before a loading screen or a capture toggle
-- must not repopulate that old baseline. Nothing held here is saved;
-- completed measurements have already gone through Journey.Append.
local function Reset()
    skills, source, readAt = nil, nil, nil
    skillsDue = false
    progress = {}
    generation = generation + 1
end

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

-- Every profession the character has, by its id; nil where the client
-- has no such API.
local function Professions()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return nil end
    local list = {}
    -- pairs: an empty slot (no second profession, no fishing) is a nil.
    for _, index in pairs({ GetProfessions() }) do
        index = ns.Plain(index)
        if type(index) == "number" then
            local name, _, rank, max, _, _, line = GetProfessionInfo(index)
            name, rank, max, line = ns.Plain(name), ns.Plain(rank), ns.Plain(max), ns.Plain(line)
            if type(line) == "number" and line > 0 and line < math.huge and line % 1 == 0
                and type(rank) == "number" and rank >= 0 and rank < math.huge and rank % 1 == 0
                and type(max) == "number" and max > 0 and max < math.huge and max % 1 == 0 then
                list[line] = { rank = rank, max = max, name = type(name) == "string" and name ~= "" and name or nil }
            end
        end
    end
    return list
end

-- The latest sitting whose heartbeat could still include this reading.
-- The next route tick extends it; a stale or future one says nothing.
local function Sitting(j, t)
    local all = ns.Sittings.List(j)
    local last = all[#all]
    if last and last.from <= t and t - last.to <= ns.Sittings.GAP then return last.from end
    return nil
end

local function ReadSkills()
    skillsDue = false
    if not settled then return end
    local j = ns.Journey.Kept()
    local now = j and Professions()
    if not now then
        Reset()
        return
    end
    local t = ns.Now()
    if source ~= j or (readAt and t < readAt) then Reset() end
    local level, where = Level(), ns.Where()
    local sitting = Sitting(j, t)
    if skills then
        -- A missing, unreadable or unlearned profession breaks only its
        -- own continuity. The other readable professions can carry on.
        for line in pairs(progress) do
            if not now[line] then progress[line] = nil end
        end
        for line, s in pairs(now) do
            local before = skills[line]
            if ProfessionCaps.IsProgress(before, s) then
                progress[line] = ProfessionCaps.Progress(j, before, s,
                    { t = t, level = level, sitting = sitting, skillLine = line }, where, progress[line])
            elseif not before or before.max ~= s.max or before.rank ~= s.rank then
                progress[line] = nil
            end
            if ProfessionCaps.IsCap(before, s) then
                local cap = ProfessionCaps.Add(j, { t = t, level = level, skillLine = line, name = s.name,
                    rank = s.rank }, where)
                if cap then ns.Debug("profession cap: %s %d", tostring(cap.name), cap.rank) end
            end
        end
    end
    skills, source, readAt = now, j, t
end

local function SkillsChanged()
    if not settled or skillsDue then return end
    skillsDue = true
    local queued = generation
    ns.After(SKILLS.settle, function()
        if queued == generation then ReadSkills() end
    end)
end

ns.On("SKILL_LINES_CHANGED", SkillsChanged)
ns.On("CHAT_MSG_SKILL", SkillsChanged)
ns.On("SD_WORLD_SETTLED", function()
    -- Each world-settled reading is a baseline, including a transition
    -- that had no skill events while the diary was unable to observe it.
    Reset()
    settled = true
    ReadSkills()
end)

local function Unsettled()
    settled = false
    Reset()
end
ns.On("PLAYER_ENTERING_WORLD", Unsettled)
ns.On("PLAYER_LEAVING_WORLD", Unsettled)
ns.On("PLAYER_LOGOUT", Unsettled)

-- A disable/re-enable with no intervening skill event is still a gap.
-- Waiting until the next skill event to notice it borrows hidden gains
-- and could manufacture both a progress burst and a cap.
ns.On("SD_SETTING_CHANGED", function(_, key)
    if key == "keepRoute" then Reset() end
end)

ns.RegisterStore("professionReadings", function(guid)
    if guid == nil or guid == ns.ownGUID then Reset() end
end)
