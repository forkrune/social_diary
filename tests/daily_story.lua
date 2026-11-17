-- A sitting's words and pictures tell the same stretch of the road.
-- These are mock construction and behaviour checks; the client still has
-- to prove wrapping, visual balance and controller reading in the book.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.Journey
local Text, Diary = ns.UI.JourneyText, ns.UI.YourDiary
local SELF, H, DAY = F.SELF, 3600, T.DAY
local MULGORE, BARRENS = 1412, 1413
local t0 = 1791000000

mock.now = t0 + 2 * DAY + 2 * H
mock.SetUnit("player", F.Like(SELF, { level = 10 }))
local companion = F.STRANGER.guid
ns.Characters.Observe(companion, { first = "Bram", surname = "Redfen", level = 10, faction = "Horde" })
ns.Diary.Add(companion, { source = "test" })
local remembered = F.FRIEND.guid
ns.Characters.Observe(remembered, { first = "Numa", surname = "Pompilius", level = 10, faction = "Horde" })
ns.Diary.Add(remembered, { source = "test" })
ns.db.characters[remembered].firstSeen = t0 + 300
ns.db.diary[remembered].addedAt = t0 + DAY + 300

ns.db.journey[SELF.guid] = nil
local j = J.Begin(SELF.guid, t0, 10, MULGORE)
local function Stop(from, mapID, place, act)
    j.segments[#j.segments + 1] = {
        kind = "stop", from = from, to = from + H, seconds = H,
        mapID = mapID, x = 0.4, y = 0.6, r = 20,
        subZone = place, act = act, levelFrom = 10, levelTo = 10,
    }
end
Stop(t0, MULGORE, "Red Rocks", { combat = H / 2 })
Stop(t0 + DAY, BARRENS, "The Crossroads", { questsIn = 2 })
Stop(t0 + 2 * DAY, MULGORE, "Bloodhoof Village", { resting = H })
j.sittings = ns.Sittings.Lines({
    { from = t0, to = t0 + H },
    { from = t0 + DAY, to = t0 + DAY + H },
    { from = t0 + 2 * DAY, to = t0 + 2 * DAY + H },
})
ns.db.sessions[1] = {
    id = 1, me = SELF.guid, startedAt = t0 + 60, endedAt = t0 + H - 60,
    zones = { "Mulgore" }, kind = "party",
    participants = { [companion] = { seconds = H - 120, since = t0 + 60, last = t0 + H - 60, levelStart = 10 } },
}
-- A real narrative feature with no recorded spot: the map cannot be the
-- only source of the words. This time is beyond the first stop's end.
j.finales = {
    { t = t0 + H + 900, title = "The Forgotten Well", n = 3, level = 10 },
    { t = t0 + DAY + 300, title = "The Northern Road", n = 2, level = 10 },
}
local note = ns.Notes.Add(companion, "I promised to bring the old lantern.", { time = t0 + 120 })
Check(note ~= nil, "the authored fixture note exists")
J.Touch()
ns.UI.ShowJournal()
ns.UI.RefreshJourneyPage()
local page = ns.UI.JourneyPage()
local entry = page.recap.entries[1]
local pieces = Diary.PiecesOf(entry)
Eq(#pieces, 3, "the same level has three distinct sittings")
Check(not entry.spliced, "the sittings remain independently reachable")
Eq(ns.JourneyRecap.WhereAt(j, j.finales[1].t), nil, "the first finale really has no known map position")

local function Body()
    local parts = {}
    for _, item in ipairs(page.items) do
        if item.text and item.font == ns.Style.FONT.body then parts[#parts + 1] = item.text end
    end
    return table.concat(parts, "\n")
end

local function HasText(needle)
    for _, item in ipairs(page.items) do
        if item.text and item.text:find(needle, 1, true) then return true end
    end
    return false
end

local function Datelines()
    local lines = {}
    for _, item in ipairs(page.items) do
        if item.text and item.font == ns.Style.FONT.faded and item.text:find("Your road begins", 1, true) then
            lines[#lines + 1] = item.text
        end
    end
    return lines
end

--------------------------------------------------------------------------
Section("a selected sitting owns its prose as well as its plates")

Diary.OpenPiece(1, 1)
local shared = Body()
Check(shared:find("Red Rocks", 1, true), "the shared evening names its own place")
Check(shared:find("Bram Redfen", 1, true), "the shared evening names its companion")
Check(shared:find("|Hsdperson:" .. companion, 1, true), "the companion's name still opens their page")
Check(shared:find("The Forgotten Well", 1, true), "an unmapped finale remains in the story")
Check(not shared:find("The Northern Road", 1, true), "the next day's finale does not leak backwards")
Check(not shared:find("The Crossroads", 1, true), "the next day's stop does not leak backwards")
Check(not shared:find("Bloodhoof Village", 1, true), "the quiet third sitting does not leak backwards")
Eq(Diary.OpenPieceOf(entry), pieces[1], "the plate selection is the same sitting")

Diary.OpenPiece(1, 2)
local solo = Body()
Check(solo:find("The Crossroads", 1, true), "the solo day has its own place")
Check(solo:find("The Northern Road", 1, true), "the solo day's finale is retained")
Check(not solo:find("The Forgotten Well", 1, true), "the previous finale does not leak forwards")
Check(not solo:find("Bram Redfen", 1, true), "yesterday's companion is not assigned to solo play")
Check(not solo:find("Red Rocks", 1, true), "yesterday's stop is not retold as today's")
Eq(Diary.OpenPieceOf(entry), pieces[2], "the second sitting is also selected for the plates")

Diary.OpenPiece(1, 3)
local quiet = Body()
Check(quiet:find("Bloodhoof Village", 1, true), "a quiet sitting still has its own story")
Check(not quiet:find("Bram Redfen", 1, true), "a quiet sitting invents no company")
Check(not quiet:find("The Forgotten Well", 1, true) and not quiet:find("The Northern Road", 1, true),
    "a quiet sitting borrows no achievement from an earlier day")

--------------------------------------------------------------------------
Section("the level keeps its dateline while dated memories follow the sitting")

local originalOpening = Text.Opening(entry, page.now)
for k = 1, #pieces do
    Diary.OpenPiece(1, k)
    local lines = Datelines()
    Eq(#lines, 1, "the level dateline appears once at sitting " .. k)
    Eq(lines[1], originalOpening, "later sittings do not invent a new beginning")
    Eq(HasText(note.text), k == 1, "the player's dated note stays with its own sitting")
    Eq(HasText("You first saw Numa"), k == 1, "the first sighting stays with its own sitting")
    local title = page.items[page.rubrics[1]]
    Eq(title.title, "LEVEL 10", "the stable level heading remains")
end
Eq(ns.db.notes[note.id].text, note.text, "reading leaves the original note untouched")
Eq(#j.finales, 2, "selection never prunes source events")

--------------------------------------------------------------------------
Section("the full-zone page retains its whole-level context")

Diary.OpenPiece(1, 2)
Diary.OpenFull(MULGORE, 1)
Eq(page.mode, "full", "the whole-level map is open")
Check(Body():find("The Forgotten Well", 1, true), "full mode includes the earlier finale")
Check(Body():find("The Northern Road", 1, true), "full mode also includes the later finale")
Check(HasText(note.text), "full mode retains the player's earlier note")
Check(HasText("You first saw Numa"), "full mode retains the earlier sighting")
Diary.FullBack()
Eq(Body(), solo, "returning from the full map restores the selected sitting's prose")
Eq(Diary.OpenPieceOf(entry), pieces[2], "the book's Back action restores the same sitting")
Check(not HasText(note.text), "returning to the solo sitting restores its note scope")

--------------------------------------------------------------------------
Section("returning to a sitting restores the same account")

Diary.OpenPiece(1, 1)
Eq(Body(), shared, "reopening the shared evening keeps its wording and facts")
Diary.OpenPiece(1, 2)
Eq(Body(), solo, "reopening the solo day keeps its wording and facts")
Diary.OpenPiece(1, 3)
Eq(Body(), quiet, "reopening the quiet sitting keeps its wording and facts")

--------------------------------------------------------------------------
Section("a sitting's wording is stable while play continues")

local same = {}
for key, value in pairs(pieces[1]) do same[key] = value end
local function Words(piece)
    return table.concat(Text.Lines(piece, page.now, page.fights, true), "\n")
end
local before = Words(same)
-- The already told stop is unchanged while the sitting's end moves on.
same.to, same.seconds = same.to + H, same.seconds + H
Eq(Words(same), before, "extending the sitting never rerolls its existing wording")
local variants = {}
for k = 0, 2 do
    same.at = t0 + k * DAY
    variants[Words(same)] = true
end
Check(ns.CountKeys(variants) > 1, "different evenings at the same level can use different wording")

--------------------------------------------------------------------------
Section("skipping the dateline preserves registered narrative features")

local firstLines = Text.Lines(pieces[1], page.now, page.fights, true)
local whole = table.concat(firstLines, "\n")
Check(not whole:find("Your road begins", 1, true), "the selected sitting does not add its own level dateline")
Check(whole:find("The Forgotten Well", 1, true), "registered nonspatial features survive composition")
Check(whole:find("Bram Redfen", 1, true), "broad supported company remains in the selected story")

-- A single sitting still follows the existing whole-entry path, without
-- losing the final outcome or requiring a new navigation mechanism.
entry.pieces, entry.spliced = { pieces[1] }, true
page.pieceOf, page.piece = entry, 1
Diary.Rebuild(true, 1)
Check(Body():find("The Forgotten Well", 1, true), "the spliced entry retains its registered features")
Eq(#Datelines(), 1, "the spliced entry has exactly one dateline too")

--------------------------------------------------------------------------
Section("a recorded outcome needs no captured route time to make a story")

local bare = J.Begin("Player-0000-DAY00001", t0, 10)
bare.finales = { { t = t0 + 60, title = "The Well Remembered", n = 1, level = 10 } }
local ctx = { now = t0 + H, level = 10, maxLevel = 60, visits = {}, notes = {}, sessions = {},
    diary = {}, characters = {}, interactions = {}, own = {} }
local featureOnly = ns.JourneyRecap.Build(bare, ctx).entries[1]
Eq(featureOnly.seconds, 0, "the recorded outcome has no captured route duration")
Eq(#featureOnly.stops, 0, "the recorded outcome has no stop to supply prose")
for _, skipOpening in ipairs({ false, true }) do
    local words = table.concat(Text.Lines(featureOnly, ctx.now, {}, skipOpening), "\n")
    Check(words:find("The Well Remembered", 1, true), "the outcome survives either dateline presentation")
    Check(not words:find("Nothing on the road", 1, true), "a substantive outcome is never called an empty level")
end

--------------------------------------------------------------------------
Section("empty sittings make no claim about their whole level")

bare.finales = {}
local empty = ns.JourneyRecap.Build(bare, ctx).entries[1]
for _, skipOpening in ipairs({ false, true }) do
    local words = table.concat(Text.Lines(empty, ctx.now, {}, skipOpening), "\n")
    Check(words:find("Nothing on the road at this level.", 1, true),
        "an empty whole level retains its established fallback")
end
local emptyPiece = ns.JourneyRecap.Pieces(bare, empty, ctx)[1]
Check(emptyPiece and emptyPiece.at, "the empty-piece fixture uses the normal recap projection")
for _, skipOpening in ipairs({ false, true }) do
    local words = table.concat(Text.Lines(emptyPiece, ctx.now, {}, skipOpening), "\n")
    Check(not words:find("Nothing on the road", 1, true), "an empty sitting makes no level-wide absence claim")
end
