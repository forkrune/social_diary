-- Witnesses: strangers observed around the user's fights. Automatic rows
-- describe their presence, not attention, intentions or a rescue. The
-- player may write a stronger interpretation in a custom witness below.
-- A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a witness is to the diary: its three row kinds,
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

local WATCHED, HELPED, SAVED = "watched_death", "tried_to_help", "saved_you"
Witnesses.WATCHED, Witnesses.HELPED, Witnesses.SAVED = WATCHED, HELPED, SAVED

-- Maximum gap between samples of the same targeting context. The stored
-- duration is not attention or intent and never strengthens the wording.
local WATCHING = { gap = 2.5 }
Witnesses.WATCHING = WATCHING

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Rows on the other player (Interactions.Add), for strangers on the
-- user's side only, each at the death's or the close call's own time
-- (Capture.lua says what each takes):
--
-- The three saved kind names are historical and stay unchanged. They
-- describe targeting/combat observations before a death or in a survived
-- fight (Capture.lua), not proven actions by the other player.
-- context.watched and context.pct remain stored for compatibility; neither
-- establishes attention, rescue, or measured remaining health.
--
-- Each carries the creature ({ npcID, name, rank } in context) where one
-- was known. Always a line (`moment`); the picker says why it offers them.
-- Each sets Core/Rows.lua's historical `witness` category ("watched" or
-- "helped"): the core's index reads it (Journey.WitnessIndex), and the
-- card keeps the existing selection order. It is not an action claim.
--
-- Targeting can be unrelated to the player's fight. A remembered target
-- also need not be the killer or the other player's foe, so these rows
-- name neither an inferred cause nor a health value.

local TT = ns.UI.TimelineText
local Place = TT.Place
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

ns.Rows.Register(WATCHED, { witness = "watched", plate = 3, moment = Always,
    reason = L["they were seen around the time you died"], text = DeathText, icon = "around" })

ns.Rows.Register(HELPED, { witness = "helped", plate = 3, moment = Always,
    reason = L["they were seen around the time you died"], text = DeathText, icon = "together" })

ns.Rows.Register(SAVED, { witness = "helped", plate = 3, moment = Always, reason = L["they were seen during a fight you survived"],
    text = function(row, guid, unplaced)
        local them = guid and ns.Characters.Name(guid) or L["Someone"]
        local zone = Where(row, nil, unplaced)
        local template = zone and L["%1$s was seen during a fight {you} survived %2$s##zone"]
            or L["%s was seen during a fight {you} survived"]
        return ns.UI.Format.You(row.me, Fmt(template, them, zone))
    end,
    icon = "together" })

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
        if w.t >= t - SLACK and types[w.row.type] then found[#found + 1] = w end
    end
    local Get = ns.Rows.Get
    table.sort(found, function(a, b)
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
