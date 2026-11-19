-- Profession caps' words (JRN-29): a sentence each in the level's prose
-- (Text.RegisterLines, UI/Journey/Text/Prose.lua), the plates' caption words
-- (Text.RegisterCaption) and the stairs' tooltip (Mark.lua). Copy changes
-- go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local ProfessionCaps = ns.ProfessionCaps
local Text = ns.UI.JourneyText
local Capital, NUMBER = Text.Capital, Text.NUMBER
local L, Fmt = ns.L, ns.Fmt

-- How far the training goes at a cap, after a comma: each rank's trainer's
-- title, with its article, in the whole clause. Any other number (a cap the
-- client adds later) is told bare, without the clause.
local SKILL_RANK = { [75] = L["as far as an Apprentice goes"], [150] = L["as far as a Journeyman goes"],
    [225] = L["as far as an Expert goes"], [300] = L["as far as an Artisan goes"] }

-- The profession as the client called it, or "a profession" where it gave
-- no name.
local function Trade(cap)
    return cap.name and cap.name ~= "" and cap.name or L["a profession"]
end

-- The cap reached, as a number: "75"; "its cap" where the record has none,
-- after "at" (`reached` false) or after "reached" and "then" (true): a
-- translation's case may differ.
local function Rank(cap, reached)
    if cap.rank then return tostring(cap.rank) end
    return reached and L["its cap##reached"] or L["its cap##at"]
end

-- A cap in a few words, for a plate's caption: "First Aid at 75", "a
-- profession at 75".
function ProfessionCaps.Words(cap)
    return Fmt(L["%1$s at %2$s"], Trade(cap), Rank(cap))
end

-- How far the training goes, after a comma: "as far as an Apprentice
-- goes"; nil for a rank with no trainer's title.
local function AsFar(cap)
    return SKILL_RANK[cap.rank]
end

-- A cap in a sentence: "First Aid reached 75, as far as an Apprentice
-- goes." The same profession again straight after only counts on: "Then
-- 150, as far as a Journeyman goes."
function ProfessionCaps.Sentence(cap, before)
    local again = before and (before.skillLine or before.name) == (cap.skillLine or cap.name)
        and (cap.skillLine or cap.name) ~= nil
    local far = AsFar(cap)
    if again then
        return far and Fmt(L["Then %1$s, %2$s."], Rank(cap, true), far) or Fmt(L["Then %s."], Rank(cap, true))
    end
    if far then return Capital(Fmt(L["%1$s reached %2$s, %3$s."], Trade(cap), Rank(cap, true), far)) end
    return Capital(Fmt(L["%1$s reached %2$s."], Trade(cap), Rank(cap, true)))
end

-- The level's caps in its prose, one sentence each.
function ProfessionCaps.Lines(e)
    local parts, before = {}, nil
    for _, cap in ipairs(e.skillCaps or {}) do
        parts[#parts + 1] = ProfessionCaps.Sentence(cap, before)
        before = cap
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- Its mark's tooltip: "First Aid at 75", then how far the training goes
-- ("As far as an Apprentice goes"), then when.
function ProfessionCaps.Tip(cap, now)
    local lines = {}
    local far = AsFar(cap)
    if far then lines[#lines + 1] = Capital(far) end
    lines[#lines + 1] = Text.Foot({ from = cap.t, levelFrom = cap.level }, now)
    return Capital(ProfessionCaps.Words(cap)), lines
end

-- Its paragraph in the level's prose: after the chains finished (50),
-- before the close calls and luck (70).
Text.RegisterLines("skill", { at = 60, lines = function(e) return ProfessionCaps.Lines(e) end })

-- The caption's words: after the chains' ends, or leading where neither
-- finds nor finales do: "First Aid at 75"; one profession twice, "First
-- Aid at 75, then 150"; several, "two professions at their cap". Its lead
-- (`at` 40) comes after a chain's end (30), before a fight with strangers
-- (45); its tail (`at` 30) after the chains' ends (20), before the deaths
-- (40).
local function Capped(caps)
    local trades, seen = 0, {}
    for _, cap in ipairs(caps) do
        local key = cap.skillLine or cap.name or cap
        if not seen[key] then seen[key], trades = true, trades + 1 end
    end
    if trades > 1 then return ns.Plural(trades, L["%s profession at its cap|%s professions at their cap##plural"], NUMBER[trades] or tostring(trades)) end
    local text = ProfessionCaps.Words(caps[1])
    for k = 2, #caps do text = Fmt(L["%1$s, then %2$s"], text, Rank(caps[k], true)) end
    return text
end

Text.RegisterCaption("skill", {
    moment = "skill",
    take = function(m) return m.cap end,
    lead = { at = 40, say = function(caps) return Capital(Capped(caps)) end },
    tail = { at = 30, say = Capped },
})

-- A tooltip's last line for everything under one mark, as the core says
-- it for every mark (Text.Foot, UI/Journey/Text/Tips.lua): when, from the
-- first to the last ("Today at 12:47", "Today from 12:47 to 13:20"), then
-- the level or levels ("Level 20", "Levels 19 to 20"). `list` is records
-- with `t` and `level`.
local function Foot(list, now)
    local a = {}
    for _, r in ipairs(list) do
        if r.t then a.from, a.to = math.min(a.from or r.t, r.t), math.max(a.to or r.t, r.t) end
        if r.level then
            a.levelFrom, a.levelTo = math.min(a.levelFrom or r.level, r.level), math.max(a.levelTo or r.level, r.level)
        end
    end
    return Text.Foot(a, now)
end

-- The tooltip of a flight of stairs (Mark.lua's `tips`): every cap
-- reached on the spot told once together (9 Nov 2026; before, each cap's
-- ProfessionCaps.Tip was stacked under the last, its time again each
-- time). One profession: its caps in the order reached, as the caption
-- says them ("First Aid at 75, then 150"), how far the training goes at
-- the last, when and at what level. Several: "Two professions at their
-- cap", each profession's caps on a line of its own ("First Aid at 75,
-- then 150"; never run on with a middle dot, the copywriter skill), then
-- from when to when.
function ProfessionCaps.Tips(caps, now)
    caps = { unpack(caps) }
    table.sort(caps, function(a, b)
        if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) < (b.t or 0) end
        return (tonumber(a.rank) or 0) < (tonumber(b.rank) or 0)
    end)
    local trades, by = {}, {}
    for _, cap in ipairs(caps) do
        local key = cap.skillLine or cap.name or cap
        if not by[key] then
            by[key] = {}
            trades[#trades + 1] = by[key]
        end
        table.insert(by[key], cap)
    end
    local lines = {}
    if #trades == 1 then
        local far = AsFar(caps[#caps])
        if far then lines[1] = Capital(far) end
        lines[#lines + 1] = Foot(caps, now)
        return Capital(Capped(caps)), lines
    end
    for _, list in ipairs(trades) do lines[#lines + 1] = Capital(Capped(list)) end
    lines[#lines + 1] = Foot(caps, now)
    return Capital(ns.Plural(#trades, L["%s profession at its cap|%s professions at their cap##plural"],
        NUMBER[#trades] or tostring(#trades))), lines
end

--------------------------------------------------------------------------
-- Skill gained between observed readings
--------------------------------------------------------------------------

-- A gain says only what the client supplied. The profession may be Mining,
-- Cooking or First Aid; the reading does not say what was gathered, made or
-- used. Keep every bounded stretch separate rather than joining its endpoints
-- across a journey, a reload or a changed training cap.
local function ProgressValid(rec)
    return ProfessionCaps.ValidProgress(rec)
end

function ProfessionCaps.ProgressWords(rec)
    if not ProgressValid(rec) then return nil end
    return Fmt(L["%1$s from %2$d to %3$d"], Trade(rec), rec.fromRank, rec.rank)
end

function ProfessionCaps.ProgressSentence(rec)
    if not ProgressValid(rec) then return nil end
    return Capital(Fmt(L["%1$s went from %2$d to %3$d."], Trade(rec), rec.fromRank, rec.rank))
end

-- Three stretches are enough for the paragraph. A second profession gets
-- room before another stretch of the first; the selected facts then return
-- to time order. This is an editorial limit, not a score for how much a gain
-- mattered. The other stretches remain on their map marks and in the road.
local PROGRESS_MOST = 3
function ProfessionCaps.ProgressSelected(records)
    local ordered, seen = {}, {}
    for i, rec in ipairs(records or {}) do
        if ProgressValid(rec) and not seen[rec] then
            seen[rec] = true
            ordered[#ordered + 1] = { rec = rec, at = i }
        end
    end
    table.sort(ordered, function(a, b)
        if (a.rec.t or 0) ~= (b.rec.t or 0) then return (a.rec.t or 0) < (b.rec.t or 0) end
        local ak, bk = tostring(a.rec.skillLine or a.rec.name or ""), tostring(b.rec.skillLine or b.rec.name or "")
        if ak ~= bk then return ak < bk end
        return a.at < b.at
    end)
    local picked, kinds, used = {}, {}, {}
    local function Take(i, item)
        picked[#picked + 1], used[i] = item, true
    end
    for i, item in ipairs(ordered) do
        local rec = item.rec
        local key = rec.skillLine or rec.name or rec
        if #picked < PROGRESS_MOST and not kinds[key] then
            kinds[key] = true
            Take(i, item)
        end
    end
    for i, item in ipairs(ordered) do
        if #picked >= PROGRESS_MOST then break end
        if not used[i] then Take(i, item) end
    end
    local keep, result = {}, {}
    for _, item in ipairs(picked) do keep[item] = true end
    for _, item in ipairs(ordered) do
        if keep[item] then result[#result + 1] = item.rec end
    end
    return result
end

function ProfessionCaps.ProgressLines(e)
    local parts = {}
    for _, rec in ipairs(ProfessionCaps.ProgressSelected(e.skillProgress)) do
        local words = ProfessionCaps.ProgressSentence(rec)
        if words then parts[#parts + 1] = words end
    end
    return parts[1] and table.concat(parts, " ") or nil
end

-- The tooltip gives the observed ranks and their time, never the duration
-- spent practising. `started` is the first gain seen, not an activity's start.
function ProfessionCaps.ProgressTip(rec, now)
    local words = ProfessionCaps.ProgressWords(rec)
    if not words then return nil end
    local foot = Text.Foot({ from = rec.started or rec.t, to = rec.t, levelFrom = rec.level }, now)
    return Capital(words), foot and { foot } or {}
end

Text.RegisterLines("skillProgress", { at = 61, lines = ProfessionCaps.ProgressLines })

local function ProgressCaption(recs)
    local parts = {}
    for _, rec in ipairs(ProfessionCaps.ProgressSelected(recs)) do
        local words = ProfessionCaps.ProgressWords(rec)
        if words then parts[#parts + 1] = words end
    end
    return ns.UI.Format.List(parts, { max = 3, shown = 2 })
end

-- Quiet progress is allowed to lead a plate of its own. A reached cap,
-- find or finale still leads where one is present, and the existing caption
-- grammar places the short rank range alongside it without a new section.
Text.RegisterCaption("skillProgress", {
    moment = "skillProgress",
    take = function(m) return ProgressValid(m.progress) and m.progress or nil end,
    lead = { at = 85, say = function(recs) return Capital(ProgressCaption(recs)) end },
    tail = { at = 75, say = ProgressCaption },
})
