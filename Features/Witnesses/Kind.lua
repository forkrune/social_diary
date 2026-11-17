-- Witnesses: people who saw a death or took part in the user's defence.
-- New rows keep the observation that qualified them; old rows have no such
-- proof and retain their bounded words. A written account stays the player's.
-- A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a witness is to the diary: its row kinds,
--                their words and icons on the timeline, and the finding of
--                a moment's witnesses by time
--   Text.lua     its words on Your Diary's plates: the card's (the name,
--                the deed, the creature), its tooltip, and the caption's
--                sentence where the card has no room
--   Card.lua     the witness card in the plate's margin (in place of the
--                killer card, or the close call's for a rescue), its pass
--                over the plate that chooses the plate's one witness, and
--                its note in the margin
--   Capture.lua  the fights watched: who looked on, who fought the user's
--                foes, who finished one off, judged at the death or when
--                the close-call judge says the fight was survived
--                (SD_FIGHT_SURVIVED)
--   Dev.lua      its part of /sd testdata: the made-up route's witnesses,
--                strangers with a row each (never packaged)
--
-- Everything is registered into the core's and the UI's registries, or
-- reached through a core message, so no file outside this folder names
-- the witness rows or the card. Its own names are on ns.Witnesses, made
-- here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the index of the buffer's witness rows by time (Journey.WitnessIndex,
--     Core/Journey.lua), built once a page as the fights' is: it reads
--     Core/Rows.lua's `witness` flag, which the three kinds here set, so
--     the route never names them (the joining of a moment to its
--     witnesses, At below, is this feature's);
--   - the death crosses the card's leader goes to (UI/Journey/Plate.lua),
--     or the close calls' marks (Features/CloseCalls/Mark.lua,
--     plate.closeMarks), and
--     the deaths matched to a cross (cross.deaths, Deaths' pass, which
--     runs before this feature's);
--   - a creature's name in a sentence (Text.KillerName) and the timeline's
--     shared row words (ns.UI.TimelineText.Foe, Place);
--   - the "around" and "together" art (UI/Style/Art.lua), shared with
--     others.
--
-- This file: the kinds, whole (Core/Rows.lua's spec in one call each,
-- words and icon included), and At.

local addonName, ns = ...

local Witnesses = {}
ns.Witnesses = Witnesses

local WATCHED, HELPED, SAVED, AID = "watched_death", "tried_to_help", "saved_you", "helped_you"
Witnesses.WATCHED, Witnesses.HELPED, Witnesses.SAVED, Witnesses.AID = WATCHED, HELPED, SAVED, AID

-- A continuous, corroborated watch shorter than `saw` is a glimpse. The
-- gap is the largest interval the capture accepts between readings. No
-- amount of watching establishes malice, so there is no moral threshold.
local WATCHING = { saw = 1.5, gap = 2.5 }
Witnesses.WATCHING = WATCHING

-- The version belongs to the new capture contract, not to the old kind
-- names. In particular an old saved_you row is never upgraded by reading
-- it. The method and action must agree before stronger words are used.
function Witnesses.Proven(c)
    if type(c) ~= "table" or c.evidence ~= 1 then return false end
    if c.method == "target_streak" then return c.action == "witness" end
    if c.method == "party_kill" then return c.action == "kill" end
    return c.method == "meter" and (c.action == "heal" or c.action == "absorb" or c.action == "dispel")
end

-- One role is shared by timeline, card and grouping. Several people can
-- share a deed only when this returns the same value: a shield and a heal
-- are both help, but a card saying "healed you" must not include the shielder.
function Witnesses.Role(kind, c)
    if Witnesses.Proven(c) then
        if kind == WATCHED and c.action == "witness" then
            return type(c.watched) == "number" and c.watched < WATCHING.saw and "saw" or "watched"
        end
        if kind == HELPED and c.action ~= "witness" then return "tried" end
        if kind == AID and c.action ~= "witness" then return c.action end
    end
    return (kind == SAVED or kind == AID) and "survived" or "died"
end

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Rows on the other player (Interactions.Add), for strangers on the
-- user's side only, each at the death's or the close call's own time
-- (Capture.lua says what each takes):
--
-- The three historical kinds remain readable. Version-one evidence adds
-- a continuous watch or a directly attributed intervention; helped_you
-- keeps the latter when the user survived. Nothing infers rescue or health
-- left from damage totals. A killed threat need not be the eventual killer,
-- so fatal-aid words do not join the action's creature to the death.
--
-- Each carries the creature ({ npcID, name, rank } in context) where one
-- was known. Always a line (`moment`); the picker says why it offers them.
-- Each sets Core/Rows.lua's historical `witness` category ("watched" or
-- "helped"): the core's index reads it (Journey.WitnessIndex), and the
-- card keeps the existing selection order. It is not an action claim.
--
-- Targeting can be unrelated to the player's fight. Historical rows name
-- neither an inferred cause nor a health value. New action rows name a
-- creature only for an attributed killing blow on the exact observed threat.

local TT = ns.UI.TimelineText
local Place, Foe = TT.Place, TT.Foe
local L, Fmt = ns.L, ns.Fmt

local function Always() return true end

-- Where a witness's row was, as one phrase ("in Coldridge Valley"): the
-- subzone where the row keeps one (`sub`, which has no id: ns.ZoneIn asks
-- the locale by its name), else the zone; nil without a place.
local function Where(row, sub, unplaced)
    if unplaced then return nil end
    if sub and sub ~= "" then return ns.ZoneIn(nil, sub) end
    return Place(row)
end

-- Both death-side kinds have the same observable outcome. Whole templates
-- keep the place optional and let shared-diary wording name the owner.
local function DeathText(row, guid, unplaced)
    local them = guid and ns.Characters.Name(guid) or L["Someone"]
    local sub = row.type == WATCHED and row.context and row.context.subZone
    local zone = Where(row, sub, unplaced)
    local template = zone and L["%1$s was seen around the time {you} died %2$s##zone"]
        or L["%s was seen around the time {you} died"]
    return ns.UI.Format.You(row.me, Fmt(template, them, zone))
end

local WATCHED_WORDS = {
    watched = { zone = L["%1$s watched {you} die %2$s##zone"], alone = L["%s watched {you} die"] },
    saw = { zone = L["%1$s saw {you} die %2$s##zone"], alone = L["%s saw {you} die"] },
}

local function WitnessReason(row)
    local role = Witnesses.Role(row and row.type, row and row.context)
    if role == "saw" or role == "watched" then return L["they watched you die"] end
    if role == "tried" then return L["they tried to save you"] end
    return L["they were seen around the time you died"]
end

ns.Rows.Register(WATCHED, { witness = "watched", plate = 3, moment = Always,
    reason = WitnessReason, text = function(row, guid, unplaced)
        local c = row.context or {}
        local words = WATCHED_WORDS[Witnesses.Role(WATCHED, c)]
        if not words then return DeathText(row, guid, unplaced) end
        local them = guid and ns.Characters.Name(guid) or L["Someone"]
        local zone = Where(row, c.subZone, unplaced)
        return ns.UI.Format.You(row.me, Fmt(zone and words.zone or words.alone, them, zone))
    end, icon = "around" })

ns.Rows.Register(HELPED, { witness = "helped", plate = 3, moment = Always,
    reason = WitnessReason, text = function(row, guid, unplaced)
        if Witnesses.Role(HELPED, row.context) ~= "tried" then return DeathText(row, guid, unplaced) end
        local them = guid and ns.Characters.Name(guid) or L["Someone"]
        local zone = Where(row, nil, unplaced)
        return ns.UI.Format.You(row.me, Fmt(zone and L["%1$s tried to save {you} %2$s##zone"]
            or L["%s tried to save {you}"], them, zone))
    end, icon = "together" })

ns.Rows.Register(SAVED, { witness = "helped", plate = 3, moment = Always, reason = L["they were seen during a fight you survived"],
    text = function(row, guid, unplaced)
        local them = guid and ns.Characters.Name(guid) or L["Someone"]
        local zone = Where(row, nil, unplaced)
        local template = zone and L["%1$s was seen during a fight {you} survived %2$s##zone"]
            or L["%s was seen during a fight {you} survived"]
        return ns.UI.Format.You(row.me, Fmt(template, them, zone))
    end,
    icon = "together" })

local AID_WORDS = {
    heal = { zone = L["%1$s healed {you} during the fight %2$s##zone"], alone = L["%s healed {you} during the fight"] },
    absorb = { zone = L["%1$s shielded {you} during the fight %2$s##zone"], alone = L["%s shielded {you} during the fight"] },
    dispel = { zone = L["%1$s removed a harmful effect from {you} during the fight %2$s##zone"],
        alone = L["%s removed a harmful effect from {you} during the fight"] },
}

ns.Rows.Register(AID, { witness = "helped", plate = 3,
    -- Ordinary support in an existing group belongs inside its exchange.
    -- The details remain available when opened; a stranger's intervention
    -- can stand alone without making every party pull a headline.
    moment = function(row) return not (row and row.context and row.context.grouped == true) end,
    reason = function(row)
        local role = Witnesses.Role(AID, row and row.context)
        if role == "heal" then return L["they healed you in a fight"] end
        if role == "absorb" then return L["they shielded you in a fight"] end
        if role == "dispel" then return L["they removed a harmful effect from you"] end
        if role == "kill" then return ns.Plural(row.context.kills or 1,
            L["they finished off %d foe that had been attacking you|they finished off %d foes that had been attacking you##plural"]) end
        return L["they were seen during a fight you survived"]
    end,
    text = function(row, guid, unplaced)
        local them = guid and ns.Characters.Name(guid) or L["Someone"]
        local role = Witnesses.Role(AID, row.context)
        local words, zone = AID_WORDS[role], Where(row, nil, unplaced)
        -- One person lands a killing blow. Several kills are several
        -- threats removed, never several helpers credited with one blow.
        if role == "kill" then
            local kills = row.context.kills or 1
            local foe = kills == 1 and Foe(row)
            if foe then
                return ns.UI.Format.You(row.me, Fmt(zone and L["%1$s finished off %2$s after it had been attacking {you} %3$s##zone"]
                    or L["%1$s finished off %2$s after it had been attacking {you}"], them, foe, zone))
            end
            return ns.UI.Format.You(row.me, ns.Plural(kills, zone
                and L["%1$s finished off %2$d foe that had been attacking {you} %3$s|%1$s finished off %2$d foes that had been attacking {you} %3$s##zone##plural"]
                or L["%1$s finished off %2$d foe that had been attacking {you}|%1$s finished off %2$d foes that had been attacking {you}##plural"],
                them, kills, zone))
        end
        if not words then
            return ns.UI.Format.You(row.me, Fmt(zone and L["%1$s was seen during a fight {you} survived %2$s##zone"]
                or L["%s was seen during a fight {you} survived"], them, zone))
        end
        return ns.UI.Format.You(row.me, Fmt(zone and words.zone or words.alone, them, zone))
    end, icon = "together" })

--------------------------------------------------------------------------
-- A moment's witnesses
--------------------------------------------------------------------------
--
-- Capture.lua writes each row at the death's or the close call's own time:
-- the same PLAYER_DEAD, the same close-call judge. So a death or a close
-- call on the route finds its witnesses by time, as fights find their
-- strangers (Journey.FightIndex), and the route keeps no names (forgetting
-- someone takes their rows, and with them their part on the plates).

-- Seconds a row's time may be from its moment's: both are read in the same
-- second, so this is only leeway.
local SLACK = 3

-- The witnesses (Journey.WitnessIndex's) to a moment at `t` whose row type
-- is in `types` ({ [type] = true }), best first: who acted before who
-- watched, the longer watcher first, then by GUID so a drawing is the
-- same each time.
function Witnesses.At(index, t, types)
    local found = {}
    if type(t) ~= "number" then return found end
    for _, w in ipairs(index or {}) do
        if w.t > t + SLACK then break end
        local c = w.row.context
        -- New capture knows the exact endpoint of its encounter. It must
        -- not attach a contribution to another fight a second or two later.
        if w.t >= t - SLACK and types[w.row.type] and (not Witnesses.Proven(c) or c.ended == t) then
            found[#found + 1] = w
        end
    end
    local Get = ns.Rows.Get
    table.sort(found, function(a, b)
        local pa, pb = Witnesses.Proven(a.row.context), Witnesses.Proven(b.row.context)
        if pa ~= pb then return pa end
        local ha, hb = Get(a.row.type).witness == "helped", Get(b.row.type).witness == "helped"
        if ha ~= hb then return ha end
        local wa = a.row.context and a.row.context.watched or 0
        local wb = b.row.context and b.row.context.watched or 0
        if wa ~= wb then return wa > wb end
        return a.guid < b.guid
    end)
    return found
end

--------------------------------------------------------------------------
-- A witness the player writes in (.claude/features/custom-cards.md)
--------------------------------------------------------------------------
--
-- Detected witnesses are People rows, found by time when a plate is drawn:
-- they have no record of their own on the route, so there is nothing for an
-- edit to lie on, and they cannot be changed this round. What the player may
-- do is write one in, which is a moment of its own, `witnessed`, kept only on
-- j.custom (Core/Custom.lua). It writes no People row, because a row would
-- claim the game saw it, would show on that person's page, and would be found
-- by Witnesses.At for any real death or close call within SLACK seconds. For
-- the same reason it never goes through At or Card.Choose: a written witness
-- and a real one can share a plate, each with their own card.
--
-- The three deeds are explicit player interpretations. They share the
-- historical row kind names but `written` keeps them separate from automatic
-- observations. "Saw" uses the smallest stain; targeting duration never
-- changes a deed or its decoration. An unticked choice defaults to "saw".
local DEEDS = {
    saw = { kind = "watched", type = WATCHED, watched = 0 },
    tried = { kind = "helped", type = HELPED },
    saved = { kind = "helped", type = SAVED },
}
local DEED_PLAIN = "saw"

-- A written witness as a chosen one, so the card, its tooltip and the caption's
-- sentence read one shape and the card needs no second way through. `rec` the
-- moment's record (Recap's copy, with customOf), `mark` where its leader goes.
-- `written` says it came of the player's words: the tooltip must not claim what
-- only capture measures. `name` is the person's as written (Text.lua's Name
-- prefers it, as a typed name has no character to ask). Health left is passed on
-- whatever the deed, as the form keeps the field while the deed changes: only a
-- rescue charts it (Card.lua's Evidence), so it waits there for a change back.
function Witnesses.Written(rec, mark)
    local deed = DEEDS[rec.deed] or DEEDS[DEED_PLAIN]
    return { kind = deed.kind, type = deed.type, watched = deed.watched, guid = rec.guid, name = rec.name,
        t = rec.t, level = rec.level, others = 0, pct = rec.pct,
        creature = rec.creature and { name = rec.creature, rank = rec.rank, bare = rec.bare == "yes" } or nil, written = rec, mark = mark }
end

-- A list of form fields without the ones a condition turned to false.
local function Kept(list)
    local kept = {}
    for i = 1, #list do
        if list[i] then kept[#kept + 1] = list[i] end
    end
    return kept
end

-- Rank 3 as a death and a close call have it, the moments a witness belongs to,
-- though any card here outranks them all by being the player's (Recap's Rank).
-- Full, not light: it puts a card in the margin. No list: inserted cards reach
-- e.witnessed through Gather alone, so `gather` has nothing to do.
ns.JourneyRecap.RegisterMoment("witnessed", { order = 25, entry = "witnessed", field = "witnessed", rank = 3,
    gather = function() end,
    custom = {
        label = L["Witness"],
        heading = L["A witness"],
        group = "social",
        describe = function(rec)
            local w = Witnesses.Written(rec)
            return Fmt(L["%1$s %2$s##name and deed"], Witnesses.Name(w), Witnesses.Deed(w))
        end,
        defaults = { deed = DEED_PLAIN },
        fields = Kept({
            { key = "name", type = "person", guid = "guid", label = L["Who"], hint = L["Anyone, in your diary or not"] },
            -- Short because a box and its word have 86 px on the form
            -- (CardSheet's SHEET.toggle); "saw you die" would run into the next.
            { key = "deed", type = "choice", values = { "saw", "tried", "saved" }, label = L["Their role"],
                names = { saw = L["Saw it"], tried = L["Tried"], saved = L["Saved"] } },
            { key = "creature", type = "text", label = L["Creature"] },
            -- Only for how the card names it: ticked, "from Hogger" and not "from a
            -- Hogger" (Text.KillerName). The user's in place of a rank, 2 Nov.
            -- Left out where a locale names a creature without one
            -- (grammar.NO_ARTICLE): the box would change nothing there.
            not ns.Locale.grammar.NO_ARTICLE
                and { key = "bare", type = "choice", values = { "yes" }, label = L["Article"],
                    names = { yes = L["Disable (\"A Hogger\")"] } } or false,
            { key = "pct", type = "number", min = 0, max = 100, label = L["Health left"],
                hint = L["%, if they saved you"] },
        }),
    } })
