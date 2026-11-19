-- Witnesses' words on Your Diary's plates: the witness card's (Card.lua)
-- in the margin words' register, the timeline's own verbs (Kind.lua's
-- rows) so the card and the profile's row say the same thing: who (the
-- subject, in the hand), what they did (the hand), what it was against
-- (small print); its tooltip; and the caption's sentence where the card
-- has no room (Text.RegisterCaption, UI/Journey/Text/Caption.lua). `w` is the
-- plate's witness (Card.lua's Choose). A creature's name in a sentence
-- ("a Ragged Young Wolf") is the core's Text.KillerName. Copy changes go
-- through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Witnesses = ns.Witnesses
local Text = ns.UI.JourneyText
local Capital, Glue, Health, NUMBER, Short, When, Who =
    Text.Capital, Text.Glue, Text.Health, Text.NUMBER, Text.Short, Text.When, Text.Who
local L, Fmt = ns.L, ns.Fmt

-- Their first name, "Someone" where the buffer no longer has it. A witness the
-- player wrote in (Kind.lua's Written) goes by the name as written, which is all
-- a typed name has, and all that is left of a picked one once they are forgotten.
function Witnesses.Name(w)
    return w and w.name or Short(w and w.guid) or L["Someone"]
end

-- How many more were there, after the name on the card's one line:
-- "& another", "& two others" (the user's words, 14 Oct); nil for none.
-- `prose`: as a sentence says it, "and another", "and two others".
function Witnesses.Others(n, prose)
    n = n or 0
    if n < 1 then return nil end
    local word = NUMBER[n] or tostring(n)
    if prose then return Fmt(L["and %s##others"], ns.Plural(n, L["another|%s others##plural"], word)) end
    return ns.Plural(n, L["& another|& %s others##plural"], word)
end

-- The capture's corroborated, unbroken watch may say saw or watched.
-- Neither a long interval nor an old unqualified row becomes a judgement
-- of the person. Written witnesses retain the player's plain "saw".
function Witnesses.Look(w)
    if not w or w.type ~= Witnesses.WATCHED then return nil end
    if w.written then return "saw" end
    local role = Witnesses.Role(w.type, w)
    return (role == "saw" or role == "watched") and role or nil
end

-- Qualified observations keep the original watch or failed-intervention
-- words; successful help says the action actually attributed. A targeting
-- snapshot without that proof retains its historical bounded description.
-- The player's own interpretation keeps its existing words.
--
-- `form` is how the sentence takes it, where English says the same words
-- and another language does not:
--   nil      after one name, or under it: "Numa saved you"
--   "many"   after several, the verb theirs: "Numa and another saved you"
--   "line"   a line of its own with no one named before it: "Saved you"
local DEEDS_SAID = {
    one = { saw = L["saw you die"], watched = L["watched you die"], saved = L["saved you"], tried = L["tried to save you"],
        heal = L["healed you"], absorb = L["shielded you"], dispel = L["removed a harmful effect from you"] },
    many = { saw = L["saw you die##many"], watched = L["watched you die##many"], saved = L["saved you##many"],
        tried = L["tried to save you##many"], heal = L["healed you##many"], absorb = L["shielded you##many"],
        dispel = L["removed a harmful effect from you##many"] },
    line = { saw = L["saw you die##line"], watched = L["watched you die##line"], saved = L["saved you##line"],
        tried = L["tried to save you##line"], heal = L["healed you##line"], absorb = L["shielded you##line"],
        dispel = L["removed a harmful effect from you##line"] },
}
local SEEN_SAID = {
    one = { died = L["was seen around the time you died"], survived = L["was seen during the fight"] },
    many = { died = L["were seen around the time you died##many"], survived = L["were seen during the fight##many"] },
    line = { died = L["was seen around the time you died##line"], survived = L["was seen during the fight##line"] },
}
--
-- The deed holds no name, so a locale whose verb agrees with the witness
-- writes <they:he/she> and it is picked here by their record's sex.
local function Theirs(w, text, under)
    local record = w and w.guid and ns.Characters.Get and ns.Characters.Get(w.guid)
    return ns.Locale.They(text, record and record.sex or nil), under
end

local function KillDeed(w, form)
    local words = form == "many" and L["finished off your foe|finished off %d foes##many##plural"]
        or (form == "line" and L["finished off your foe|finished off %d foes##line##plural"]
            or L["finished off your foe|finished off %d foes##plural"])
    return ns.Plural(w.kills or 1, (Theirs(w, words)))
end

function Witnesses.Deed(w, form)
    local role = Witnesses.Role(w and w.type, w)
    if w and w.written then
        role = w.type == Witnesses.WATCHED and "saw" or (w.type == Witnesses.SAVED and "saved" or "tried")
    end
    if role == "kill" then return KillDeed(w, form) end
    local said = DEEDS_SAID[form] or DEEDS_SAID.one
    if said[role] then return Theirs(w, said[role]) end
    said = SEEN_SAID[form] or SEEN_SAID.one
    return Theirs(w, said[role])
end

-- A written interpretation may connect the person to a creature. The one
-- automatic creature clause is an attributed killing blow on that exact
-- threat; it never connects the threat to the user's cause of death.
function Witnesses.Foe(w)
    local name = w and w.creature and Text.KillerName(w.creature)
    if not name then return nil end
    if not w.written then
        -- This is the exact threat killed, not the killer inferred from a
        -- target. A separate clause keeps that distinction on a fatal aid.
        if Witnesses.Proven(w) and (w.kills or 1) == 1 and ((w.kills or 0) > 0 or w.action == "kill") then
            return Fmt(Theirs(w, L["finished off %s"]), name)
        end
        return nil
    end
    return Fmt(w.type == Witnesses.WATCHED and L["to %s##witness"] or L["from %s##witness"], name)
end

-- The witness in a sentence of its own after the caption's, where the card
-- has no room: "Grisha was seen around the time you died.", or the player's own
-- "Numa and another tried to save you." for a written witness.
function Witnesses.Caption(w)
    local who = Witnesses.Name(w)
    local others = Witnesses.Others(w and w.others, true)
    if others then who = Fmt(L["%1$s %2$s##name and others"], who, others) end
    return Fmt(L["%1$s %2$s."], who, (Witnesses.Deed(w, others and "many" or nil)))
end

-- The card's tooltip: their full name, who they are, the qualifying
-- observation or actions, and when. Old targeting snapshots do not gain
-- proof merely by being read. One the player wrote in keeps their
-- interpretation, distinct from the automatic observation. Its
-- mark's tooltip is this too, where the card may have found no room, so the deed
-- and the creature are spelt out.
-- What a written witness did, with its creature: "Saved you from Hogger".
-- `form`: Witnesses.Deed's ("line" where the deed starts a line).
local function Did(w, form)
    local foe = Witnesses.Foe(w)
    local deed = Witnesses.Deed(w, form)
    return foe and Fmt(L["%1$s %2$s##deed and foe"], deed, foe) or deed
end

-- What the qualifying observation actually supplied. A tooltip can keep
-- several contributions even though the short deed chooses one. Counts
-- and amounts are deliberately not made into a claim about health left.
local function AidLines(w, lines)
    if (w.healed or 0) > 0 or w.action == "heal" then lines[#lines + 1] = Theirs(w, L["healed you##line"]) end
    if (w.absorbed or 0) > 0 or w.action == "absorb" then lines[#lines + 1] = Theirs(w, L["shielded you##line"]) end
    if (w.dispelled or 0) > 0 or w.action == "dispel" then
        lines[#lines + 1] = Theirs(w, L["removed a harmful effect from you##line"])
    end
    if (w.kills or 0) > 0 or w.action == "kill" then
        lines[#lines + 1] = Witnesses.Foe(w) or KillDeed(w, "line")
    end
end

function Witnesses.Tip(w, now)
    if w.written then
        local lines = { Capital(Did(w, "line")) }
        if ns.Witnesses.Card.Evidence(w) then lines[#lines + 1] = Fmt(L["You came out of it with %s"], Health(w)) end
        lines[#lines + 1] = When(w.t, w.level, now)
        return Who(w.guid) or Witnesses.Name(w), lines
    end
    local record = ns.Characters.Get and ns.Characters.Get(w.guid) or nil
    local lines = {}
    if record then
        local who = {}
        if record.level then who[#who + 1] = Fmt(L["Level %d"], record.level) end
        who[#who + 1] = ns.UI.Format.RaceName(record)
        who[#who + 1] = ns.UI.Format.ClassName(record)
        if #who > 0 then lines[#lines + 1] = table.concat(who, " ") end
    end
    local proved = Witnesses.Proven(w)
    local first = #lines + 1
    if Witnesses.Look(w) then
        lines[#lines + 1] = Fmt(Theirs(w, L["Had you or a foe targeted for %s"]),
            Glue(Fmt(L["%s seconds"], ns.UI.Format.Decimal(w.watched or 0, 1))))
        lines[#lines + 1] = L["Not in a fight themselves"]
    elseif proved then
        AidLines(w, lines)
    else
        lines[#lines + 1] = L["Had you or a foe targeted"]
    end
    for i = first, #lines do lines[i] = Capital(lines[i]) end
    local more = w.others or 0
    if more > 0 then
        lines[#lines + 1] = ns.Plural(more, proved and L["One other was there too|%s others were there too##plural"]
            or L["One other was seen too|%s others were seen too##plural"],
            Capital(NUMBER[more] or tostring(more)))
    end
    local at = w.death or w.call
    lines[#lines + 1] = When(w.t, (at and at.level) or w.level, now)
    return Who(w.guid) or Witnesses.Name(w), lines
end

-- The written witnesses' mark on a plate (Card.lua's `witnessed`): every
-- one on the spot together, `list` as Witnesses.Written reads them (9 Nov
-- 2026: two on one spot each said their name and time again). Who, then
-- what they did, each deed once with how often ("Saved you from Hogger
-- twice"), then when and at what level (ns.Deaths.Foot, the ending the
-- death-side marks share). One person: their name, a line a deed, the
-- health a rescue left where there was one rescue (DEEDS of them, the last
-- "And more besides" where there were more). Several: "Two
-- witnesses", a line each ("Grisha saved you from Hogger"), PEOPLE of them,
-- then "Others were there too". Four lines at most.
local PEOPLE, DEEDS = 3, 3

-- A person's deeds, each once: { text, n }, in the order first done.
local function Deeds(ws, form)
    local by, list = {}, {}
    for _, w in ipairs(ws) do
        local did = Did(w, form)
        if not by[did] then
            by[did] = { text = did, n = 0 }
            list[#list + 1] = by[did]
        end
        by[did].n = by[did].n + 1
    end
    return list
end

local function Often(d)
    return d.n > 1 and Fmt(L["%1$s %2$s##times"], d.text, ns.UI.Format.Times(d.n)) or d.text
end

function Witnesses.Tips(list, now)
    local people, of = {}, {}
    for _, w in ipairs(list) do
        local key = w.guid or Witnesses.Name(w)
        if not of[key] then
            of[key] = {}
            people[#people + 1] = of[key]
        end
        of[key][#of[key] + 1] = w
    end
    local lines = {}
    if #people == 1 then
        local ws = people[1]
        local deeds = Deeds(ws, "line")
        for i = 1, math.min(#deeds, DEEDS) do lines[i] = Capital(Often(deeds[i])) end
        if #deeds > DEEDS then lines[DEEDS] = L["And more besides"] end
        if #ws == 1 and ns.Witnesses.Card.Evidence(ws[1]) then
            lines[#lines + 1] = Fmt(L["You came out of it with %s"], Health(ws[1]))
        end
        lines[#lines + 1] = ns.Deaths.Foot(list, now)
        return Who(ws[1].guid) or Witnesses.Name(ws[1]), lines
    end
    for i, ws in ipairs(people) do
        if i == PEOPLE and #people > PEOPLE then
            lines[i] = L["Others were there too"]
            break
        end
        local deeds = Deeds(ws)
        local said = {}
        for k, d in ipairs(deeds) do said[k] = Often(d) end
        lines[i] = Fmt(L["%1$s %2$s##name and deed"], Witnesses.Name(ws[1]), ns.UI.TimelineText.Join(said, L["%1$s and %2$s"]))
    end
    lines[#lines + 1] = ns.Deaths.Foot(list, now)
    return Capital(ns.Plural(#people, L["%s witness|%s witnesses##plural"],
        NUMBER[#people] or tostring(#people))), lines
end

-- Someone who was there at a death or a close call on the plate
-- (Card.lua's Choose) whose card found no room beside it: `said.witness`,
-- told in a sentence of its own after the rest, in the timeline's words
-- ("Two deaths, to a Sunscale Lashtail. Grisha was seen around the time you
-- died."). With the card beside the plate the words say nothing of them;
-- the creature the card names is the margin's to leave out (`said.death`,
-- `said.close`), as with the killer's. A coda (`at` 10) and nothing else:
-- it gathers no moment of the plate's.
Text.RegisterCaption("witness", {
    coda = { at = 10, say = function(c)
        local w = c.said.witness
        return w and Witnesses.Caption(w) or nil
    end },
})

-- Witnesses the player wrote in (Kind.lua's Written) whose cards found no room:
-- each a sentence of its own, as a detected one's, after it (coda 20). Written
-- ones are told separately from `said.witness` because a plate may hold one real
-- witness and any number of written ones. With its card shown nothing is said.
Text.RegisterCaption("witnessed", {
    coda = { at = 20, say = function(c)
        local left = c.said.witnessed
        if not (left and left[1]) then return nil end
        local sentences = {}
        for i, w in ipairs(left) do sentences[i] = Witnesses.Caption(w) end
        return table.concat(sentences, " ")
    end },
})

--------------------------------------------------------------------------
-- Help that stood on its own
--------------------------------------------------------------------------

-- At most three distinct accounts in the paragraph, favouring different
-- encounters before another action in the same one. Several healers in one
-- encounter are one deed with its actual contributors; separate killing
-- blows never become a shared kill. These limits shorten the words only:
-- every source row and every mark's tooltip keeps its own evidence.
local ASSISTANCE_MOST = 3
function Witnesses.AssistanceSelected(records)
    local rows, seen = {}, {}
    for _, rec in ipairs(records or {}) do
        local w = Witnesses.Card.Assistance(rec)
        if w and not seen[w.row] then
            seen[w.row] = true
            rows[#rows + 1] = w
        end
    end
    table.sort(rows, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        if a.started ~= b.started then return a.started < b.started end
        if a.guid ~= b.guid then return tostring(a.guid or "") < tostring(b.guid or "") end
        return tostring(a.action or "") < tostring(b.action or "")
    end)
    local groups, by = {}, {}
    for _, w in ipairs(rows) do
        local encounter = tostring(w.started) .. ":" .. tostring(w.ended)
        local key = encounter .. ":" .. w.action
        if w.action == "kill" then key = key .. ":" .. tostring(w.guid or "") end
        local group = by[key]
        if not group then
            group = { witness = w, encounter = encounter, people = {} }
            groups[#groups + 1], by[key] = group, group
        end
        if not group.people[w.guid or w.row] then
            group.people[w.guid or w.row] = true
            if group.witness ~= w then group.witness.others = group.witness.others + 1 end
        end
    end
    local picked, encounters, phrases, count = {}, {}, {}, 0
    local function Take(i, group)
        local sentence = Witnesses.Caption(group.witness)
        if phrases[sentence] then return false end
        picked[i], phrases[sentence], count = true, true, count + 1
        return true
    end
    for i, group in ipairs(groups) do
        if count >= ASSISTANCE_MOST then break end
        if not encounters[group.encounter] and Take(i, group) then encounters[group.encounter] = true end
    end
    for i, group in ipairs(groups) do
        if count >= ASSISTANCE_MOST then break end
        if not picked[i] then Take(i, group) end
    end
    local result = {}
    for i, group in ipairs(groups) do
        if picked[i] then result[#result + 1] = group.witness end
    end
    return result
end

function Witnesses.AssistanceLines(e)
    local words = {}
    for _, w in ipairs(Witnesses.AssistanceSelected(e.assistance)) do
        words[#words + 1] = Witnesses.Caption(w)
    end
    return words[1] and table.concat(words, " ") or nil
end

Text.RegisterLines("assisted", { at = 76, run = "combat", lines = Witnesses.AssistanceLines })

-- The action is on the witness card, or its existing coda when that card
-- has no room. This neutral lead stops a help-only plate falling back to
-- "On the road", without inventing a close call or an extra story section.
Text.RegisterCaption("assisted", {
    moment = "assisted",
    take = function(m) return Witnesses.Card.Assistance(m.assisted) end,
    lead = { at = 95, say = function() return L["Help in a fight"] end },
})
