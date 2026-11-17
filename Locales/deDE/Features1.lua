-- German (deDE): Features1. Keys are the English text (Locales/enUS.lua).
-- The hunter's tames, close calls, deaths, hunts and witnesses, in the
-- order of Locales/enUS.lua. Shared words ("%1$s and %2$s", "twice",
-- "once|%d times", "Level %d") are in Words.lua and Journal.lua.
--
-- A creature's name goes bare in German (Grammar.lua's NO_ARTICLE and
-- KillerName), so the templates set it after "gegen", "durch", "vor" or as
-- a subject, never after an article. Ledger words (cards, rows, tooltips)
-- in the Perfekt, the level's prose in the Präteritum (voices/deDE.md).

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- Features/Classes/Hunter/Kind.lua: the custom card's form
    ["Tamed Pet"] = "Gezähmter Begleiter",
    ["A pet tamed"] = "Ein Begleiter gezähmt",
    ["the name you gave it, or leave this empty"] = "der Name, den du ihm gabst, oder leer lassen",
    ["Beast"] = "Wildtier",
    ["Family"] = "Familie",
    ["Wolf, Cat, Boar…"] = "Wolf, Katze, Eber…",

    -- Features/Classes/Hunter/Text.lua
    ["%s, tamed here"] = "%s, hier gezähmt",
    ["A pet, tamed here"] = "Ein Begleiter, hier gezähmt",
    ["%1$s, %2$s, %3$s"] = "%1$s, %2$s, %3$s",
    ["a pet"] = "ein Begleiter",
    ["A pet"] = "Ein Begleiter",

    -- Features/CloseCalls/Kind.lua: the custom card's form
    ["Close Call"] = "Knapper Kampf",
    ["A close call"] = "Ein knapper Kampf",
    ["%1$s, %2$d%% health"] = "%1$s, %2$d %% Gesundheit",
    ["Creature"] = "Kreatur",
    ["-1 for a skull"] = "-1 für einen Totenkopf",
    ["Level"] = "Stufe",
    ["How many"] = "Wie viele",
    ["%"] = "%",
    ["Health left"] = "Gesundheit übrig",

    -- Features/CloseCalls/Text.lua
    -- Nominative ("Numa und ein weiterer", "gegen Hogger und zwei weitere"):
    -- the witnesses' "and %s##others" takes it too.
    ["another|%s others##plural"] = "ein weiterer|%s weitere",
    ["Got away from %1$s with %2$s."] = "Kam gegen %1$s mit %2$s davon.",
    ["Got out of a fight with %s."] = "Kam mit %s aus einem Kampf.",
    ["Rare Elite"] = "Seltene Elite",
    ["Lv %d"] = "St. %d",
    ["Lv ??"] = "St. ??",
    ["%1$s (%2$s)"] = "%1$s (%2$s)",
    ["Against %s both times"] = "Beide Male gegen %s",
    ["Against %s each time"] = "Jedes Mal gegen %s",
    ["Against %1$s %2$s##times"] = "Gegen %1$s (%2$s)",
    -- A name or a deed and how often: "Hogger (zweimal)", "Hat dich
    -- gerettet, gegen Hogger (zweimal)".
    ["%1$s %2$s##times"] = "%1$s (%2$s)",
    ["Against %s and others"] = "Gegen %s und andere",
    ["Against %s"] = "Gegen %s",
    ["%1$s%% health left, against %2$s"] = "%1$s %% Gesundheit übrig, gegen %2$s",
    ["%s%% health left"] = "%s %% Gesundheit übrig",
    ["Down to %s%% health at worst"] = "Am knappsten: %s %% Gesundheit",
    ["%s close call|%s close calls##plural"] = "%s knapper Kampf|%s knappe Kämpfe",
    ["fought against %s"] = "gegen %s gekämpft",
    ["Left you with %s%% health"] = "Ließ dir %s %% Gesundheit",
    ["One more was in the fight|%s more were in the fight##plural"] = "Ein weiterer war im Kampf|%s weitere waren im Kampf",
    ["And %s.##more"] = "Und %s.",
    ["one more close call|%s more close calls##plural"] = "noch ein knapper Kampf|noch %s knappe Kämpfe",
    ["a close call"] = "ein knapper Kampf",
    ["a close call with %s"] = "ein knapper Kampf gegen %s",

    -- Features/Deaths/Kind.lua: the custom card's form
    ["Death"] = "Tod",
    ["A death"] = "Ein Tod",
    ["Killed by"] = "Getötet von",
    ["Type"] = "Art",
    ["Elite"] = "Elite",
    ["Rare"] = "Selten",

    -- Features/Deaths/Text.lua
    ["killed you twice"] = "hat dich zweimal getötet",
    -- 3 and up, a word to five ("dreimal"), then a figure ("6mal").
    ["%s time|%s times##plural"] = "%smal|%smal",
    ["killed you %s##times"] = "hat dich %s getötet",
    ["Boss"] = "Boss",
    ["Rare elite"] = "Seltene Elite",
    ["A fall"] = "Ein Sturz",
    ["Drowned"] = "Ertrunken",
    ["Exhaustion"] = "Erschöpfung",
    ["Fire"] = "Feuer",
    ["Lava"] = "Lava",
    ["Slime"] = "Schleim",
    ["Killed you here"] = "Hat dich hier getötet",
    ["Killed you here %s"] = "Hat dich hier %s getötet",
    ["The last time %s"] = "Zuletzt %s",
    ["As near as the diary could tell"] = "Soweit das Tagebuch es sagen konnte",
    ["The world"] = "Die Welt",
    ["And others"] = "Und weitere",
    ["a death|%s deaths##plural"] = "ein Tod|%s Tode",
    ["%1$s, to %2$s"] = "%1$s, durch %2$s",

    -- Features/Firsts/Kind.lua (the hunts' form too)
    ["Item"] = "Gegenstand",

    -- Features/Hunts/Kind.lua: the custom cards' form
    ["%1$s, %2$d killed"] = "%1$s, %2$d getötet",
    ["Expected"] = "Erwartet",
    ["kills"] = "Kills",
    ["Bad Luck"] = "Pech",
    ["Unlucky Quest Drops"] = "Pech bei der Questbeute",
    ["Good Luck"] = "Glück",
    ["Lucky Quest Drops"] = "Glück bei der Questbeute",

    -- Features/Hunts/Text.lua
    ["%d kill|%d kills##plural"] = "%d Kill|%d Kills",
    ["one drop|%d drops##plural"] = "ein Beutestück|%d Beutestücke",
    ["%s and others"] = "%s und andere",
    ["%1$s for %2$s"] = "%1$s für %2$s",
    ["%d more than expected|%d more than expected##plural"] = "%d mehr als erwartet|%d mehr als erwartet",
    ["%d fewer than expected|%d fewer than expected##plural"] = "%d weniger als erwartet|%d weniger als erwartet",
    ["For %s"] = "Für %s",
    ["Dropped by the first %s"] = "%s ließ es gleich beim ersten Mal fallen",
    ["%d other|%d others##plural"] = "%d weiterer|%d weitere",
    ["Killed %s"] = "%s getötet",
    ["%d more kills than expected|%d more kills than expected##plural"] = "%d Kill mehr als erwartet|%d Kills mehr als erwartet",
    ["%d fewer kills than expected|%d fewer kills than expected##plural"] = "%d Kill weniger als erwartet|%d Kills weniger als erwartet",
    ["%d more kills than expected in all|%d more kills than expected in all##plural"] = "Insgesamt %d Kill mehr als erwartet|Insgesamt %d Kills mehr als erwartet",
    ["%d fewer kills than expected in all|%d fewer kills than expected in all##plural"] = "Insgesamt %d Kill weniger als erwartet|Insgesamt %d Kills weniger als erwartet",
    ["%d drop|%d drops##plural"] = "%d Beutestück|%d Beutestücke",
    ["a drop"] = "Beute",
    ["%s lucky hunt|%s lucky hunts##plural"] = "%s<f> glückliche Jagd|%s glückliche Jagden",
    ["%s slow hunt|%s slow hunts##plural"] = "%s<f> zähe Jagd|%s zähe Jagden",
    ["killed"] = "getötet",
    ["expected more"] = "mehr erwartet",
    ["expected %d"] = "%d erwartet",
    ["each"] = "pro Stück",
    ["usually"] = "üblich",
    ["killed %1$s for\194\160%2$d"] = "%1$s getötet für\194\160%2$d",
    ["killed %s"] = "%s getötet",
    ["Usually %d each"] = "Sonst %d pro Stück",
    ["The first %1$s gave up its %2$s."] = "Gleich beim ersten Mal ließ %1$s %2$s fallen.",
    ["drop"] = "Beute",
    ["The first %1$s gave up its %2$s, where %3$s."] = "Gleich beim ersten Mal ließ %1$s %2$s fallen, obwohl %3$s.",
    ["%d was expected|%d were expected##plural"] = "%d erwartet war|%d erwartet waren",
    ["It took only %1$s to get %2$s."] = "Es brauchte nur %1$s, um %2$s zu bekommen.",
    ["It took only %1$s to get %2$s, %3$s."] = "Es brauchte nur %1$s, um %2$s zu bekommen, %3$s.",
    ["first##on the first"] = "ersten",
    ["on the first"] = "beim ersten",
    ["after %s"] = "nach %s",
    ["after just %s"] = "nach nur %s",
    ["dropped"] = "fiel",
    ["first##the first"] = "erste",
    ["the first"] = "der erste",
    ["%1$s %2$s##dropped when"] = "%1$s %2$s",
    ["It took %1$s to get %2$s."] = "Es brauchte %1$s, um %2$s zu bekommen.",
    ["It took %1$s to get %2$s, %3$s."] = "Es brauchte %1$s, um %2$s zu bekommen, %3$s.",
    ["one more slow hunt|%s more slow hunts##plural"] = "noch eine zähe Jagd|noch %s zähe Jagden",
    ["one more lucky hunt|%s more lucky hunts##plural"] = "noch eine glückliche Jagd|noch %s glückliche Jagden",
    ["another lucky hunt|%s more lucky hunts##plural"] = "eine weitere glückliche Jagd|%s weitere glückliche Jagden",

    -- Features/Met/Kind.lua (the witness's form too)
    ["Who"] = "Wer",

    -- Features/Witnesses/Kind.lua: the timeline's rows, the picker's
    ["%1$s watched {you} die %2$s##zone"] = "%1$s hat {dir} %2$s beim Sterben zugesehen",
    ["%s watched {you} die"] = "%s hat {dir} beim Sterben zugesehen",
    ["%1$s saw {you} die %2$s##zone"] = "%1$s hat {dich} %2$s sterben sehen",
    ["%s saw {you} die"] = "%s hat {dich} sterben sehen",
    ["they watched you die"] = "sie haben dir beim Sterben zugesehen",
    ["%1$s tried to save {you} %2$s##zone"] = "%1$s hat versucht, {dich} %2$s zu retten",
    ["%s tried to save {you}"] = "%s hat versucht, {dich} zu retten",
    ["they tried to save you"] = "sie haben versucht, dich zu retten",
    ["watched you die##many"] = "haben dir beim Sterben zugesehen",
    ["watched you die##line"] = "hat dir beim Sterben zugesehen",
    ["watched you die"] = "hat dir beim Sterben zugesehen",
    ["%s seconds"] = "%s Sekunden",
    ["Not in a fight themselves"] = "Selbst nicht im Kampf",
    ["One other was there too|%s others were there too##plural"] = "Noch jemand war dabei|%s weitere waren dabei",
    ["%s healed {you} during the fight"] = "%s hat {dich} im Kampf geheilt",
    ["%1$s healed {you} during the fight %2$s##zone"] = "%1$s hat {dich} im Kampf %2$s geheilt",
    ["%s shielded {you} during the fight"] = "%s hat {dich} im Kampf mit einem Schild geschützt",
    ["%1$s shielded {you} during the fight %2$s##zone"] = "%1$s hat {dich} im Kampf %2$s mit einem Schild geschützt",
    ["%s removed a harmful effect from {you} during the fight"] = "%s hat im Kampf einen schädlichen Effekt von {dir} entfernt",
    ["%1$s removed a harmful effect from {you} during the fight %2$s##zone"] = "%1$s hat im Kampf %2$s einen schädlichen Effekt von {dir} entfernt",
    ["%1$s finished off %2$d foe that had been attacking {you}|%1$s finished off %2$d foes that had been attacking {you}##plural"] = "%1$s hat %2$d Feind den Rest gegeben, der zuvor {dich} angegriffen hatte|%1$s hat %2$d Feinden den Rest gegeben, die zuvor {dich} angegriffen hatten",
    ["%1$s finished off %2$d foe that had been attacking {you} %3$s|%1$s finished off %2$d foes that had been attacking {you} %3$s##zone##plural"] = "%1$s hat %3$s %2$d Feind den Rest gegeben, der zuvor {dich} angegriffen hatte|%1$s hat %3$s %2$d Feinden den Rest gegeben, die zuvor {dich} angegriffen hatten",
    ["%1$s finished off %2$s after it had been attacking {you}"] = "%1$s hat %2$s den Rest gegeben, nachdem {dich} dieses Wesen angegriffen hatte",
    ["%1$s finished off %2$s after it had been attacking {you} %3$s##zone"] = "%1$s hat %3$s %2$s den Rest gegeben, nachdem {dich} dieses Wesen angegriffen hatte",
    ["they healed you in a fight"] = "hat dich in einem Kampf geheilt",
    ["they shielded you in a fight"] = "hat dich in einem Kampf mit einem Schild geschützt",
    ["they removed a harmful effect from you"] = "hat einen schädlichen Effekt von dir entfernt",
    ["they finished off %d foe that had been attacking you|they finished off %d foes that had been attacking you##plural"] = "hat %d Feind den Rest gegeben, der zuvor dich angegriffen hatte|hat %d Feinden den Rest gegeben, die zuvor dich angegriffen hatten",
    ["healed you"] = "hat dich geheilt",
    ["healed you##line"] = "hat dich geheilt",
    ["healed you##many"] = "haben dich geheilt",
    ["shielded you"] = "hat dich mit einem Schild geschützt",
    ["shielded you##line"] = "hat dich mit einem Schild geschützt",
    ["shielded you##many"] = "haben dich mit einem Schild geschützt",
    ["removed a harmful effect from you"] = "hat einen schädlichen Effekt von dir entfernt",
    ["removed a harmful effect from you##line"] = "hat einen schädlichen Effekt von dir entfernt",
    ["removed a harmful effect from you##many"] = "haben einen schädlichen Effekt von dir entfernt",
    ["finished off your foe|finished off %d foes##plural"] = "hat deinem Feind den Rest gegeben|hat %d Feinden den Rest gegeben",
    ["finished off your foe|finished off %d foes##line##plural"] = "hat deinem Feind den Rest gegeben|hat %d Feinden den Rest gegeben",
    ["finished off your foe|finished off %d foes##many##plural"] = "haben deinem Feind den Rest gegeben|haben %d Feinden den Rest gegeben",
    ["Had you or a foe targeted for %s"] = "Hatte dich oder einen Feind %s lang im Ziel",
    ["finished off %s"] = "gab %s den Rest",
    -- reasons, the custom card's form
    ["%1$s was seen around the time {you} died %2$s##zone"] = "Etwa zur Zeit {deines} Todes %2$s wurde %1$s gesehen",
    ["%s was seen around the time {you} died"] = "%s wurde etwa zur Zeit {deines} Todes gesehen",
    ["they were seen around the time you died"] = "wurde etwa zur Zeit deines Todes gesehen",
    ["they were seen during a fight you survived"] = "wurde bei einem Kampf gesehen, den du überlebt hast",
    ["%1$s was seen during a fight {you} survived %2$s##zone"] = "Bei einem Kampf %2$s, den {du überlebt hast}, wurde %1$s gesehen",
    ["%s was seen during a fight {you} survived"] = "%s wurde bei einem Kampf gesehen, den {du überlebt hast}",
    ["Witness"] = "Zeuge",
    ["A witness"] = "Ein Zeuge",
    ["%1$s %2$s##name and deed"] = "%1$s %2$s",
    ["Anyone, in your diary or not"] = "Jeder, ob im Tagebuch oder nicht",
    ["Their role"] = "Rolle",
    ["Saved"] = "Rettete",
    ["Saw it"] = "Sah zu",
    ["Tried"] = "Half",
    ["Article"] = "Artikel",
    ["Disable (\"A Hogger\")"] = "Aus („ein Hogger“)",
    ["%, if they saved you"] = "%, falls sie dich retteten",

    -- Features/Witnesses/Text.lua
    ["was seen around the time you died"] = "wurde etwa zur Zeit deines Todes gesehen",
    ["was seen during the fight"] = "wurde während des Kampfes gesehen",
    ["were seen around the time you died##many"] = "wurden etwa zur Zeit deines Todes gesehen",
    ["were seen during the fight##many"] = "wurden während des Kampfes gesehen",
    ["was seen around the time you died##line"] = "wurde etwa zur Zeit deines Todes gesehen",
    ["was seen during the fight##line"] = "wurde während des Kampfes gesehen",
    ["Had you or a foe targeted"] = "Hatte dich oder einen Feind im Ziel",
    ["One other was seen too|%s others were seen too##plural"] = "Noch jemand wurde gesehen|%s weitere Personen wurden gesehen",
    ["Someone"] = "Jemand",
    ["and %s##others"] = "und %s",
    ["& another|& %s others##plural"] = "& ein weiterer|& %s weitere",
    -- After several names, the verb theirs: "Numa und ein weiterer haben
    -- dich gerettet".
    ["saw you die##many"] = "haben dich sterben sehen",
    ["saved you##many"] = "haben dich gerettet",
    ["tried to save you##many"] = "haben versucht, dich zu retten",
    -- A line of its own, no one named before it: "Hat dich gerettet".
    ["saw you die##line"] = "hat dich sterben sehen",
    ["saved you##line"] = "hat dich gerettet",
    ["tried to save you##line"] = "hat versucht, dich zu retten",
    ["saw you die"] = "hat dich sterben sehen",
    ["saved you"] = "hat dich gerettet",
    ["tried to save you"] = "hat versucht, dich zu retten",
    ["from %s##witness"] = "gegen %s",
    ["to %s##witness"] = "gegen %s",
    ["%1$s %2$s##name and others"] = "%1$s %2$s",
    ["%1$s %2$s."] = "%1$s %2$s.",
    -- The foe after the finished deed: German would set it inside ("Hat
    -- dich vor Hogger gerettet"), the template joins it after.
    ["%1$s %2$s##deed and foe"] = "%1$s, %2$s",
    ["You came out of it with %s"] = "Du kamst mit %s davon",
    ["And more besides"] = "Und noch mehr",
    ["Others were there too"] = "Weitere waren dabei",
    ["%s witness|%s witnesses##plural"] = "%s Zeuge|%s Zeugen",

    -- UI/Journey/Text/Margin.lua (the killer card)
    ["killed you"] = "hat dich getötet",

    -- UI/Journey/Text/Match.lua (the hunts' form too)
    ["Kills"] = "Getötet",

    -- UI/Journey/Text/Run.lua (the deaths' words too)
    ["%1$s, with %2$s"] = "%1$s, mit %2$s",

    -- UI/Journey/Text/Tips.lua (the death cross)
    ["Died here"] = "Hier gestorben",
    ["Died here %s"] = "Hier %s gestorben",
})
