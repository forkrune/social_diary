# Contributing to Social Diary

Thank you for helping.

## Setting up

The addon folder sits inside the game install, where copy and sync tools
possibly mark files executable. Git would then list each file as changed
with no lines added or removed which is annoying. Here's the fix for it. Tell git to ignore the executable bit in your
clone:

```sh
git config core.fileMode false
```

## Running the tests

The suite runs offline, against a mock of the WoW API (`tests/wowmock.lua`).
You need [LuaJIT](https://luajit.org).

```sh
bash Dev/ci/test.sh             # everything, a fresh LuaJIT process per file
luajit tests/run.lua people.lua # only the files you name
luajit tests/run.lua -v people  # verbose output for one file
```

A new test file only runs once it is listed in `FILES` in `tests/run.lua`.
The CI runner reads that list directly. Running every file in one LuaJIT
process can exceed runner memory, so use the isolated runner for the full
suite. Test assertions and failure handling are unchanged.

CI runs the suite on every push to `main` and on every pull request
(`.github/workflows/tests.yml`). After a successful main run it also packages
an installable addon ZIP, with the source commit and checksums, as an Actions
artifact retained for 14 days. Pull requests validate the changes before
integration.

The mock does not do layout. For anything a player sees, try it in the game
client as well.

## Finding your way round

[AGENTS.md](AGENTS.md) is the map of the code: what lives in `Core/`,
`Capture/`, `UI/`, `Features/`, `Dev/` and `tests/`, and the load order in
`social_diary.toc`. It also holds the rules for AI-assisted work, so it is
worth reading whether you use an assistant or not.

- `.claude/skills/` holds the copywriter, plates, release and new-feature
  skills. To add a detection, follow `.claude/skills/new-feature/`: the
  pipeline in `SKILL.md`, the folder and its registries in `folder.md`.
- `.claude/rules/` holds the project rules, such as how to write the changelog
  and whether a new setting is per character or per account.
- `.impeccable.md` describes the look and feel of the book.
- `Dev/` holds in-game debug tools (`/sd art`, `/sd journey`, `/sd testdata`).
  They load from the repository but are fenced out of releases.

### Requirement IDs in comments

Comments often cite requirement IDs (such as `JRN-28` or `DIA-9`) and design
notes. They point to the initial planning documents, which are not
in the repository. You can ignore them.

## Text a player reads

Every string a player reads follows the house voice in
`.claude/skills/copywriter/SKILL.md`. In short:

- British English, sentence case, whole sentences.
- The diary speaks to _you_ and calls itself _the diary_, never _I_.
- Quiet: no exclamation marks, no warnings in capitals.
- One word per thing: strangers are _pencilled in_ and _rubbed out_, people
  you add are _inked in_, your movement is your _road_.
- No internal words on screen: _data_, _session_, _record_, _SavedVariables_.

The suite asserts some copy. If you change a string, search `tests/` for it
and update the test.

## Translating

Every string a player reads goes through `L["English text"]`; the English
is the key and the fallback. The rules for writing them (whole sentences,
positional `%1$s`, `ns.Plural` for counts, zones through `ns.ZoneIn`) are in
`/copywriter` §7.

- **Where a locale lives:** `Locales/<id>/` (`deDE`, `frFR`, `ruRU`), a
  file per area of the addon, each listed in `social_diary.toc` after
  `Locales/enUS.lua`. Each file starts `ns.Locale.Add("<id>", { ... })`.
  Grammar the templates can't carry (plural rule, capitals, ordinals, the
  zone and dungeon phrases) goes in `Locales/<id>/Grammar.lua`, replacing
  the defaults in `Locales/Locale.lua`.
- **After changing a string in the code,** regenerate the master list:

  ```sh
  luajit Dev/Locale/extract.lua
  ```

  `--check` only says whether it is up to date; `--missing <id>` lists the
  keys a locale has no words for yet, and `--context <id> [path]` shows each
  with the code round it (what its values are, where it shows).
- **Tests:** `bash Dev/ci/test.sh` (its `locale` file checks every locale
  in the TOC: no unknown keys, the same placeholders, one plural form per
  category; keys still to translate are listed as a note, not a failure, and
  read in English until then), then the whole suite under the locale:

  ```sh
  bash Dev/ci/test.sh --locale deDE
  ```

  It must end with `NO ADDON ERRORS UNDER deDE`.

## UI conventions

The journal is an open book on parchment, not a window. In brief:

- The Addon prioritises drawing actual memories over statistics and quantified data.
- Build from what the client draws: textures, gradients, masks and font
  strings. No Blizzard frame templates, to avoid taint.
- Every art file has a list of candidates and a flat-colour fallback.
- Light theme: dark ink on warm parchment. Shared colours, fonts and sizes
  live in `UI/Style/`; use them rather than new values.
- Lapis blue is for ornament only, since blue on the page also reads Alliance.
- New settings are per character unless there is a reason otherwise
  (`.claude/rules/settings.md`).
- Work on _Your Diary_'s map plates follows `.claude/skills/plates/`.
- Where UI code goes, how pages, settings sections, marks and cards plug
  in, and how to prove a refactor changed nothing: `.claude/rules/ui.md`.

## Changelog

Anything a player would notice gets one line in `CHANGELOG.md`, under
`## [Unreleased]`. Follow `.claude/rules/changelog.md`: about ten words, what
changed and not how, under _Shiny new Things_, _Changes_ or _Fixes_.

## Images

`*.png` is in `.gitignore` on purpose, so the history stays small. Attach
screenshots to your pull request or issue.

## Pull request checklist

- [ ] `bash Dev/ci/test.sh` passes, new code has tests, and new test files
      are in `FILES` in `tests/run.lua`.
- [ ] State what was tried in the game client and what still needs testing.
      Include a screenshot for UI changes when the client is available.
- [ ] Player-facing text follows the copywriter skill.
- [ ] `CHANGELOG.md` has a line under `## [Unreleased]` for anything a player
      would notice.
- [ ] No images committed.

## Releases

`main` is the integration and testing branch. Merge bounded changes after
offline validation, then use the resulting build to test in the game and
iterate. Pending live-client checks should be documented; they do not prevent
merging work intended for a testing build.

Use `vX.Y.Z-alpha.N` or `vX.Y.Z-beta.N` for testing releases. Use `vX.Y.Z`
for a stable release. The tag must match `## Version:` in `social_diary.toc`
and point to a commit on `main`. Raise the TOC version and changelog together,
then run `luajit Dev/changelog.lua` to update the in-game changelog. Keep
`## Interface:` unchanged unless the game requires an update.

After the version change is merged and main CI succeeds, create and push the
tag at that verified commit. For the first prepared alpha:

```sh
git fetch origin main
git tag -a v4.2.0-alpha.1 origin/main -m "Social Diary 4.2.0-alpha.1"
git push origin v4.2.0-alpha.1
```

Check that the commit still carries `## Version: 4.2.0-alpha.1` before using
those commands; use the new version for later releases. Do not move an
already-published tag.

`.github/workflows/release.yml` validates the tag and source, runs the isolated
suite, packages with BigWigs, checks the installable ZIP, and publishes it on
GitHub with checksums and build provenance. Alpha and beta tags create GitHub
prereleases. Only the publishing job can write repository contents. Releases
go to this fork; no CurseForge or Wago upload is configured.

The maintainer must enable GitHub Actions in a newly created fork. A checked-in
workflow alone does not establish that a run or release succeeded. Inspect the
finished run and its assets. The repository's release-version skill describes
the version/changelog preflight; this section defines the fork's testing policy.

### Testing a build

Keep the ZIP's version, commit, and checksum with your notes. Back up the
Social Diary saved variables before installing a testing build, and fully
restart the client so all manifest entries load.

For `4.2.0-alpha.1`, check these scenarios:

1. Gain profession ranks below a training cap, then reach the cap. Verify
   the recorded endpoints and that the same gain appears only once.
2. Receive identifiable healing, shielding, dispelling or a threat kill from
   another player. Compare the diary's action and person with what happened.
   Ambiguous or unavailable evidence should produce no attributed help.
3. Compare a sustained witness at a death with somebody who arrives only
   afterwards. Try an environmental death and a duel as well.
4. Leave a dungeon after an attempt or death without defeating a boss. Check
   the retained visit, its zero boss count, and its placement in the outing.
5. Open an outing with several distinct moments and repeated companions.
   Check that the highlights fit the outing and do not repeat one encounter.
6. Check the new cards with your normal locale, font size and controller.
   Forget a participant and confirm their derived assistance story disappears.

Report the build version or commit, locale, expected behaviour, observed
behaviour, and reproducible steps. Remove real player names, GUIDs and chat
from shared examples. Offline assertions cover model behaviour; the live
checks establish actual game payloads, rendering and interaction.

## Licence

By contributing, you agree that your code is released under the
[GNU General Public License v3.0 or later](LICENSE).
