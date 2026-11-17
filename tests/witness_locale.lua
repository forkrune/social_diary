-- Automatic witness words across the translated clients. These fictional
-- records exercise the real row/card readers, including another character's
-- diary: a place belongs to the owner's outcome, never a witness location.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local wasLocale = _G.GetLocale
local ALT, OBSERVER = "Player-4707-0A17A17A", "Player-4707-0B11B11B"

-- Each outcome has current/other owner, each with no place/with place.
-- Current owner is male, other owner and observer female. Exact sentences
-- catch missing conjugations that merely stripping braces would conceal.
local CASES = {
    deDE = {
        death = {
            { "Mira wurde etwa zur Zeit deines Todes gesehen", "Etwa zur Zeit deines Todes in Mulgore wurde Mira gesehen" },
            { "Mira wurde etwa zur Zeit Ailas Todes gesehen", "Etwa zur Zeit Ailas Todes in Mulgore wurde Mira gesehen" },
        },
        survived = {
            { "Mira wurde bei einem Kampf gesehen, den du überlebt hast", "Bei einem Kampf in Mulgore, den du überlebt hast, wurde Mira gesehen" },
            { "Mira wurde bei einem Kampf gesehen, den Aila überlebt hat", "Bei einem Kampf in Mulgore, den Aila überlebt hat, wurde Mira gesehen" },
        },
        reason = { "wurde etwa zur Zeit deines Todes gesehen", "wurde bei einem Kampf gesehen, den du überlebt hast" },
        deed = { "wurde etwa zur Zeit deines Todes gesehen", "wurde während des Kampfes gesehen" },
        many = { "wurden etwa zur Zeit deines Todes gesehen", "wurden während des Kampfes gesehen" },
        target = "Hatte dich oder einen Feind im Ziel",
        others = { "Noch jemand wurde gesehen", "Zwei weitere Personen wurden gesehen", "Fünf weitere Personen wurden gesehen", "21 weitere Personen wurden gesehen" },
    },
    frFR = {
        death = {
            { "Mira a été vue vers le moment où tu es mort", "Mira a été vue vers le moment où tu es mort à Mulgore" },
            { "Mira a été vue vers le moment où Aila est morte", "Mira a été vue vers le moment où Aila est morte à Mulgore" },
        },
        survived = {
            { "Mira a été vue pendant un combat auquel tu as survécu", "Mira a été vue pendant un combat auquel tu as survécu à Mulgore" },
            { "Mira a été vue pendant un combat auquel Aila a survécu", "Mira a été vue pendant un combat auquel Aila a survécu à Mulgore" },
        },
        reason = { "cette personne a été vue vers le moment de ta mort", "cette personne a été vue pendant un combat auquel tu as survécu" },
        deed = { "a été vue vers le moment de ta mort", "a été vue pendant le combat" },
        many = { "ont été vus vers le moment de ta mort", "ont été vus pendant le combat" },
        target = "Te ciblait ou ciblait un adversaire",
        others = { "Une autre personne a aussi été vue", "Deux autres personnes ont aussi été vues", "Cinq autres personnes ont aussi été vues", "21 autres personnes ont aussi été vues" },
    },
    esES = {
        death = {
            { "Mira fue vista en torno al momento en que moriste", "Mira fue vista en torno al momento en que moriste en Mulgore" },
            { "Mira fue vista en torno al momento en que Aila murió", "Mira fue vista en torno al momento en que Aila murió en Mulgore" },
        },
        survived = {
            { "Mira fue vista durante un combate al que sobreviviste", "Mira fue vista durante un combate al que sobreviviste en Mulgore" },
            { "Mira fue vista durante un combate al que Aila sobrevivió", "Mira fue vista durante un combate al que Aila sobrevivió en Mulgore" },
        },
        reason = { "esa persona fue vista en torno al momento de tu muerte", "esa persona fue vista durante un combate al que sobreviviste" },
        deed = { "fue vista en torno al momento de tu muerte", "fue vista durante el combate" },
        many = { "fueron vistos en torno al momento de tu muerte", "fueron vistos durante el combate" },
        target = "Objetivo seleccionado: tú o un adversario",
        others = { "También se vio a otra persona", "Dos personas más fueron vistas", "Cinco personas más fueron vistas", "21 personas más fueron vistas" },
    },
    itIT = {
        death = {
            { "Mira è stata vista più o meno quando sei morto", "Mira è stata vista più o meno quando sei morto in Mulgore" },
            { "Mira è stata vista più o meno quando Aila è morta", "Mira è stata vista più o meno quando Aila è morta in Mulgore" },
        },
        survived = {
            { "Mira è stata vista durante un combattimento a cui sei sopravvissuto", "Mira è stata vista durante un combattimento a cui sei sopravvissuto in Mulgore" },
            { "Mira è stata vista durante un combattimento a cui Aila è sopravvissuta", "Mira è stata vista durante un combattimento a cui Aila è sopravvissuta in Mulgore" },
        },
        reason = { "quella persona è stata vista più o meno al momento della tua morte", "quella persona è stata vista durante un combattimento a cui sei sopravvissuto" },
        deed = { "è stata vista più o meno al momento della tua morte", "è stata vista durante il combattimento" },
        many = { "sono stati visti più o meno al momento della tua morte", "sono stati visti durante il combattimento" },
        target = "Aveva come bersaglio te o un avversario",
        others = { "È stata vista anche un’altra persona", "Due altre persone sono state viste", "Cinque altre persone sono state viste", "21 altre persone sono state viste" },
    },
    plPL = {
        death = {
            { "Mira była widziana mniej więcej w chwili twojej śmierci", "Mira była widziana mniej więcej w chwili twojej śmierci w Mulgore" },
            { "Mira była widziana mniej więcej w chwili śmierci postaci Aila", "Mira była widziana mniej więcej w chwili śmierci postaci Aila w Mulgore" },
        },
        survived = {
            { "Mira była widziana podczas walki, którą przeżyłeś", "Mira była widziana podczas walki, którą przeżyłeś w Mulgore" },
            { "Mira była widziana podczas walki, którą Aila przeżyła", "Mira była widziana podczas walki, którą Aila przeżyła w Mulgore" },
        },
        reason = { "postać była widziana mniej więcej w chwili twojej śmierci", "postać była widziana podczas walki, którą przeżyłeś" },
        deed = { "była widziana mniej więcej w chwili twojej śmierci", "była widziana podczas walki" },
        many = { "byli widziani mniej więcej w chwili twojej śmierci", "byli widziani podczas walki" },
        target = "Wybrany cel: ty lub przeciwnik",
        others = { "Widziano też inną osobę", "Dwie inne osoby też były widziane", "Pięć innych osób też było widzianych", "21 innych osób też było widzianych" },
    },
    ruRU = {
        death = {
            { "Mira была замечена примерно тогда, когда ты погиб", "Mira была замечена примерно тогда, когда ты погиб в зоне «Mulgore»" },
            { "Mira была замечена примерно тогда, когда Aila погибла", "Mira была замечена примерно тогда, когда Aila погибла в зоне «Mulgore»" },
        },
        survived = {
            { "Mira была замечена во время боя, в котором ты выжил", "Mira была замечена во время боя, в котором ты выжил в зоне «Mulgore»" },
            { "Mira была замечена во время боя, в котором Aila выжила", "Mira была замечена во время боя, в котором Aila выжила в зоне «Mulgore»" },
        },
        reason = { "персонаж был замечен примерно тогда, когда ты погиб", "персонаж был замечен во время боя, в котором ты выжил" },
        deed = { "была замечена примерно в момент твоей смерти", "была замечена во время боя" },
        many = { "были замечены примерно в момент твоей смерти", "были замечены во время боя" },
        target = "В цели были ты или недруг",
        others = { "Один другой персонаж тоже был замечен", "Два других персонажа тоже были замечены", "Пять других персонажей тоже были замечены", "21 другой персонаж тоже был замечен" },
    },
    zhCN = {
        death = {
            { "你死亡前后，Mira曾被看见", "你在Mulgore死亡前后，Mira曾被看见" },
            { "Aila死亡前后，Mira曾被看见", "Aila在Mulgore死亡前后，Mira曾被看见" },
        },
        survived = {
            { "在你生还的那场战斗中，Mira曾被看见", "你在Mulgore生还的那场战斗中，Mira曾被看见" },
            { "在Aila生还的那场战斗中，Mira曾被看见", "Aila在Mulgore生还的那场战斗中，Mira曾被看见" },
        },
        reason = { "对方曾在你死亡前后被看见", "对方曾在你生还的那场战斗中被看见" },
        deed = { "曾在你死亡前后被看见", "曾在战斗中被看见" },
        many = { "曾在你死亡前后被看见", "曾在战斗中被看见" },
        target = "曾选中你或一个对手",
        others = { "还看见了一位其他人", "还看见了两位其他人", "还看见了五位其他人", "还看见了21位其他人" },
    },
}

local function Plain(text, what)
    Check(not text:find("[{}<>]"), what .. " left a grammar marker: " .. text)
end

for _, id in ipairs({ "deDE", "frFR", "esES", "itIT", "plPL", "ruRU", "zhCN" }) do
    Section(id .. " witness rows, deeds and tooltip")
    mock.Reset()
    -- Locale.Add resolves unbraced reader forms as the client loads; the
    -- player already exists then, before T.Boot's login events.
    mock.SetUnit("player", F.SELF)
    _G.GetLocale = function() return id end
    local ns = T.Boot()
    ns.diaryShared = true
    ns.OwnCharacters()[ALT] = { first = "Aila" }
    ns.db.characters[ALT] = { guid = ALT, names = { { first = "Aila" } }, sex = 3 }
    ns.db.characters[OBSERVER] = { guid = OBSERVER, names = { { first = "Mira" } }, sex = 3 }
    local expected = CASES[id]

    for _, kind in ipairs({ "watched_death", "tried_to_help", "saved_you" }) do
        local outcome = kind == "saved_you" and "survived" or "death"
        local at = outcome == "survived" and 2 or 1
        local spec = ns.Rows.Get(kind)
        -- The picker uses this field directly, without Fmt or Format.You.
        Eq(spec.reason, expected.reason[at], kind .. " raw picker reason")
        Plain(spec.reason, kind .. " raw picker reason")
        for owner, guid in ipairs({ F.SELF.guid, ALT }) do
            local row = { type = kind, me = guid, time = ns.Now(), zone = "Mulgore",
                context = { watched = 40, pct = 6, name = "Unrelated creature", npcID = 6 } }
            for place = 1, 2 do
                local text = spec.text(row, OBSERVER, place == 1)
                local label = kind .. " owner " .. owner .. " place " .. place
                Eq(text, expected[outcome][owner][place], label)
                Plain(text, label)
            end
        end

        local w = { type = kind, guid = OBSERVER, t = ns.Now(), watched = 40, pct = 6 }
        Eq(ns.Witnesses.Deed(w), expected.deed[at], kind .. " singular deed")
        Eq(ns.Witnesses.Deed(w, "line"), expected.deed[at], kind .. " standalone deed")
        Eq(ns.Witnesses.Deed(w, "many"), expected.many[at], kind .. " plural deed")
        for count, n in ipairs({ 1, 2, 5, 21 }) do
            w.others = n
            local _, lines = ns.Witnesses.Tip(w, ns.Now())
            Eq(lines[#lines - 2], expected.target, kind .. " targeting observation")
            Eq(lines[#lines - 1], expected.others[count], kind .. " others " .. n)
            for _, line in ipairs(lines) do Plain(line, kind .. " tooltip") end
        end
    end
end

_G.GetLocale = wasLocale
