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

-- Exact expected words are independent of the translation table. In
-- particular the shared diary changes the recipient, while the named
-- helper remains female. The plural deeds have no implied second action.
local PROVEN = {
    deDE = {
        heal = { { "Mira hat dich im Kampf geheilt", "Mira hat dich im Kampf in Mulgore geheilt" },
            { "Mira hat Aila im Kampf geheilt", "Mira hat Aila im Kampf in Mulgore geheilt" } },
        deeds = { "hat dich geheilt", "hat dich mit einem Schild geschützt", "hat einen schädlichen Effekt von dir entfernt", "hat deinem Feind den Rest gegeben" },
        many = { "haben dich geheilt", "haben dich mit einem Schild geschützt", "haben einen schädlichen Effekt von dir entfernt", "haben deinem Feind den Rest gegeben" },
        saw = "hat dich sterben sehen", watched = "hat dir beim Sterben zugesehen", tried = "hat versucht, dich zu retten", foe = "gab Hogger den Rest",
    },
    frFR = {
        heal = { { "Mira t’a soigné pendant le combat", "Mira t’a soigné pendant le combat à Mulgore" },
            { "Mira a soigné Aila pendant le combat", "Mira a soigné Aila pendant le combat à Mulgore" } },
        deeds = { "t’a soigné", "t’a protégé avec un bouclier", "a dissipé un effet néfaste sur toi", "a achevé ton adversaire" },
        many = { "t’ont soigné", "t’ont protégé avec un bouclier", "ont dissipé un effet néfaste sur toi", "ont achevé ton adversaire" },
        saw = "t’a vu mourir", watched = "t’a regardé mourir", tried = "a essayé de te sauver", foe = "a achevé Hogger",
    },
    esES = {
        heal = { { "Mira te curó durante el combate", "Mira te curó durante el combate en Mulgore" },
            { "Mira curó a Aila durante el combate", "Mira curó a Aila durante el combate en Mulgore" } },
        deeds = { "te curó", "te protegió con un escudo", "eliminó un efecto dañino de ti", "remató a tu adversario" },
        many = { "te curaron", "te protegieron con un escudo", "eliminaron un efecto dañino de ti", "remataron a tu adversario" },
        saw = "te vio morir", watched = "te miró morir", tried = "intentó salvarte", foe = "remató a Hogger",
    },
    itIT = {
        heal = { { "Mira ti ha curato durante il combattimento", "Mira ti ha curato durante il combattimento in Mulgore" },
            { "Mira ha curato Aila durante il combattimento", "Mira ha curato Aila durante il combattimento in Mulgore" } },
        deeds = { "ti ha curato", "ti ha protetto con uno scudo", "ha rimosso un effetto dannoso da te", "ha finito il tuo avversario" },
        many = { "ti hanno curato", "ti hanno protetto con uno scudo", "hanno rimosso un effetto dannoso da te", "hanno finito il tuo avversario" },
        saw = "ti ha visto morire", watched = "ti ha guardato morire", tried = "ha cercato di salvarti", foe = "ha finito Hogger",
    },
    plPL = {
        heal = { { "Mira leczyła cię podczas walki", "Mira leczyła cię podczas walki w Mulgore" },
            { "Mira leczyła Aila podczas walki", "Mira leczyła Aila podczas walki w Mulgore" } },
        deeds = { "leczyła cię", "osłoniła cię tarczą", "usunęła z ciebie szkodliwy efekt", "dobiła twojego przeciwnika" },
        many = { "leczyli cię", "osłonili cię tarczą", "usunęli z ciebie szkodliwy efekt", "dobili twojego przeciwnika" },
        saw = "widziała, jak giniesz", watched = "przyglądała się, jak giniesz", tried = "próbowała cię uratować", foe = "dobiła przeciwnika Hogger",
    },
    ruRU = {
        heal = { { "Mira лечила тебя во время боя", "Mira лечила тебя во время боя в зоне «Mulgore»" },
            { "Mira лечила Aila во время боя", "Mira лечила Aila во время боя в зоне «Mulgore»" } },
        deeds = { "лечила тебя", "защитила тебя щитом", "сняла с тебя вредоносный эффект", "добила 1 недруга" },
        many = { "лечили тебя", "защитили тебя щитом", "сняли с тебя вредоносный эффект", "добили 1 недруга" },
        saw = "видела, как ты умираешь", watched = "смотрела, как ты умираешь", tried = "пыталась спасти тебя", foe = "добила недруга Hogger",
    },
    zhCN = {
        heal = { { "Mira在战斗中治疗了你", "Mira在Mulgore的战斗中治疗了你" },
            { "Mira在战斗中治疗了Aila", "Mira在Mulgore的战斗中治疗了Aila" } },
        deeds = { "治疗了你", "为你施加了护盾", "驱散了你身上的有害效果", "击杀了1个敌人" },
        many = { "治疗了你", "为你施加了护盾", "驱散了你身上的有害效果", "击杀了1个敌人" },
        saw = "目睹你死去", watched = "旁观你死去", tried = "试图救你", foe = "击杀了Hogger",
    },
}

local MULTI_KILL = {
    deDE = "hat %d Feinden den Rest gegeben", frFR = "a achevé %d adversaires",
    esES = "remató a %d adversarios", itIT = "ha finito %d avversari",
    plPL = "dobiła %d przeciwników", ruRU = "добила %d недругов", zhCN = "击杀了%d个敌人",
}

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
        local reason = ns.Rows.Reason({ type = kind })
        Eq(reason, expected.reason[at], kind .. " raw picker reason")
        Plain(reason, kind .. " raw picker reason")
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

    Section(id .. " qualified actions, watching and shared recipients")
    local W, expectedProof = ns.Witnesses, PROVEN[id]
    for actionIndex, action in ipairs({ "heal", "absorb", "dispel", "kill" }) do
        local c = { evidence = 1, method = action == "kill" and "party_kill" or "meter", action = action,
            started = ns.Now() - 20, ended = ns.Now(), name = "Hogger", npcID = 448, rank = "rare" }
        local w = { type = W.AID, guid = OBSERVER, t = ns.Now(), creature = { name = "Hogger", rank = "rare" } }
        for key, value in pairs(c) do w[key] = value end
        Eq(W.Deed(w), expectedProof.deeds[actionIndex], "the verified " .. action .. " deed")
        Eq(W.Deed(w, "line"), expectedProof.deeds[actionIndex], "the verified " .. action .. " standalone deed")
        Eq(W.Deed(w, "many"), expectedProof.many[actionIndex], "the verified " .. action .. " group deed")
        if action == "kill" then Eq(W.Foe(w), expectedProof.foe, "the exact victim clause agrees with the helper") end
        local _, lines = W.Tip(w, ns.Now())
        for _, line in ipairs(lines) do Plain(line, action .. " tooltip") end
        for owner, guid in ipairs({ F.SELF.guid, ALT }) do
            local row = { type = W.AID, me = guid, time = ns.Now(), zone = "Mulgore", context = c }
            local reason = ns.Rows.Reason(row)
            Plain(reason, action .. " raw reason")
            Check(not reason:find("^they "), action .. " reason fell back to English")
            for place = 1, 2 do
                local text = ns.Rows.Get(W.AID).text(row, OBSERVER, place == 1)
                Plain(text, action .. " shared recipient")
                if action == "heal" then Eq(text, expectedProof.heal[owner][place], "healing identifies the right recipient") end
            end
        end
    end
    for _, count in ipairs({ 1, 2, 5, 21 }) do
        local c = { evidence = 1, method = "party_kill", action = "kill", kills = count,
            started = ns.Now() - 20, ended = ns.Now(), name = "Hogger", npcID = 448, rank = "rare" }
        local w = { type = W.AID, guid = OBSERVER, t = ns.Now(), creature = { name = "Hogger", rank = "rare" } }
        for key, value in pairs(c) do w[key] = value end
        local expectedDeed = count == 1 and expectedProof.deeds[4]
            or ((id == "ruRU" and count == 21) and "добила 21 недруга" or MULTI_KILL[id]:format(count))
        Eq(W.Deed(w), expectedDeed, "killing blows counted correctly at " .. count)
        Eq(W.Deed(w, "line"), expectedDeed, "the tooltip uses the same kill count")
        Plain(W.Caption(w), "counted kill caption")
        local _, lines = W.Tip(w, ns.Now())
        for _, line in ipairs(lines) do Plain(line, "counted kill tooltip") end
        if count > 1 then
            Eq(W.Foe(w), nil, "several kills have no single victim subtitle")
            Check(W.Caption(w):find(tostring(count), 1, true) ~= nil, "the caption retains the kill count")
        end
        for _, guid in ipairs({ F.SELF.guid, ALT }) do
            local row = { type = W.AID, me = guid, time = ns.Now(), zone = "Mulgore", context = c }
            local reason = ns.Rows.Reason(row)
            Plain(reason, "counted kill reason")
            Check(reason:find(tostring(count), 1, true) ~= nil, "the reason retains the kill count")
            for place = 1, 2 do
                local text = ns.Rows.Get(W.AID).text(row, OBSERVER, place == 1)
                Plain(text, "counted kill timeline")
                if count > 1 then
                    Check(text:find(tostring(count), 1, true) ~= nil, "the timeline retains the kill count")
                    Check(not text:find("Hogger", 1, true), "multiple kills cannot all become the one named foe")
                end
            end
        end
    end
    local watch = { type = W.WATCHED, guid = OBSERVER, t = ns.Now(), evidence = 1,
        method = "target_streak", action = "witness", watched = 0.8 }
    Eq(W.Deed(watch), expectedProof.saw, "a corroborated glimpse keeps the original words")
    watch.watched = 30
    local deed, underline = W.Deed(watch)
    Eq(deed, expectedProof.watched, "a long corroborated watch has no moral escalation")
    Eq(underline, nil, "no translated accusation to underline")
    local _, watchLines = W.Tip(watch, ns.Now())
    for _, line in ipairs(watchLines) do Plain(line, "qualified watch tooltip") end
    local help = { type = W.HELPED, guid = OBSERVER, evidence = 1, method = "meter", action = "heal" }
    Eq(W.Deed(help), expectedProof.tried, "the failed intervention keeps the original words")
    help.evidence = 2
    Eq(W.Deed(help), expected.deed[1], "unknown proof versions do not strengthen legacy words")
end

_G.GetLocale = wasLocale
