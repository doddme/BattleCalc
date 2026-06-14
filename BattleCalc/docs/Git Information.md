# BattleCalc Git and Xcode Survival Guide

This guide pulls together the practical Git and Xcode cleanup advice from today into one place.

The goal is not to learn all of Git. The goal is to know a small set of commands and recovery patterns so work can be saved, bad changes can be undone, and a good checkpoint can always be recovered.

## Core idea

Think of a Git commit as a save point in a game.

If the project is in a good state and a commit is made, it is always possible to get back to that exact point later, even after changing files, deleting files, or making a complete mess of the project.

## Project folder

All commands should be run from the BattleCalc project folder.

`[bash] cd /Users/mikedodd/Documents/BattleCalc`

If there is any doubt about the current location, check it with:

`[bash] pwd`

## Xcode saving

Building or running in Xcode usually saves changes, but it is still smart to save before an important Git action.

A safe habit is:

- Save in Xcode.
- Then run Git commands in Terminal.

That way the commit reflects what is actually visible in the editor.

## The most useful Git command

This is the main command to see what Git thinks has changed:

`[bash] git status`

Compact version:

`[bash] git status --short`

Common meanings:

- `M` = modified
- `A` = added
- `D` = deleted
- `??` = untracked file that Git does not know about yet

Use `git status` anytime there is uncertainty about what changed.

## Save a checkpoint

When the project is in a good state and a restore point is wanted:

`[bash] git status`

`[bash] git add .`

`[bash] git commit -m "Checkpoint: describe what changed"`

Example:

`[bash] git add .`

`[bash] git commit -m "Checkpoint: CSV terrain and unit loading plus combat smoke tests"`

What these do:

- `git add .` prepares current changes for commit.
- `git commit` stores them as a snapshot in history.

## See past checkpoints

To see commit history:

`[bash] git log --oneline`

The top line is the newest checkpoint.

Example:

`abcd123 Checkpoint: CSV terrain and unit loading plus combat smoke tests`

`9f00aa1 Earlier checkpoint`

The short code on the left is the commit ID.

## Discard local changes and go back to the last commit

If files were edited and those edits should be thrown away:

`[bash] git restore .`

That restores tracked files back to the last commit.

If extra untracked files or folders were created and should also be removed:

`[bash] git clean -fd`

Important caution:

- `git clean -fd` deletes untracked files and folders.
- Check `git status` first if there is any doubt.

## Go back to a specific checkpoint

If there is a need to return to an older commit exactly:

1. Find the commit:

`[bash] git log --oneline`

2. Reset to it:

`[bash] git reset --hard abcd123`

Replace `abcd123` with the real commit ID.

This makes the whole project match that checkpoint exactly.

## Normal working rhythm

A simple daily pattern:

1. Work in Xcode.
2. In Terminal, check changes:

`[bash] git status`

3. If things are good, save a checkpoint:

`[bash] git add .`

`[bash] git commit -m "Short description of progress"`

4. If things go badly and there is a need to go back:

`[bash] git restore .`

5. If extra untracked junk should also be removed:

`[bash] git clean -fd`

## Checking a specific file in Git

To see only entries related to a specific file name, filter the short status:

`[bash] git status --short | grep 'NapoleonicsTerrainData.swift'`

This is useful when tracking down filename or path issues.

## The hidden-character terrain file problem

The terrain file problem turned out to be a Git tracking problem, not a real filesystem filename problem.

Git showed bad tracked paths with a hidden character before the filename, while the real file on disk was clean.

Useful command that exposed this:

`[bash] git status --short | grep 'NapoleonicsTerrainData.swift'`

Bad paths looked like this:

`AD "BattleCalc/Rulesets/Napoleonics/\342\200\211NapoleonicsTerrainData.swift"`

`AD "BattleCalc/\342\200\211NapoleonicsTerrainData.swift"`

Good clean path looked like this:

`?? BattleCalc/Rulesets/Napoleonics/NapoleonicsTerrainData.swift`

That meant Git still remembered two bad hidden-character paths, while the actual clean file existed separately.

## Cleanup commands for that specific problem

These were the commands used to clean out the bad tracked paths and add the clean file:

`[bash] git restore --staged "BattleCalc/Rulesets/Napoleonics/ NapoleonicsTerrainData.swift"`

`[bash] git restore --staged "BattleCalc/ NapoleonicsTerrainData.swift"`

`[bash] git rm --cached "BattleCalc/Rulesets/Napoleonics/ NapoleonicsTerrainData.swift"`

`[bash] git rm --cached "BattleCalc/ NapoleonicsTerrainData.swift"`

`[bash] git add BattleCalc/Rulesets/Napoleonics/NapoleonicsTerrainData.swift`

`[bash] git status --short | grep 'NapoleonicsTerrainData.swift'`

After cleanup, only the clean path should remain.

## How to inspect whether the problem is really there

Before making Git changes, it is reasonable to want proof.

This command shows just the terrain file entries in Git status:

`[bash] git status --short | grep 'NapoleonicsTerrainData.swift'`

If the hidden-character problem exists, bad entries will contain escaped sequences like `\342\200\211` before the filename. [cite:1271]

A clean real file on disk should look like:

`NapoleonicsTerrainData.swift`

## Xcode and Source Control badges

If a strange symbol appears next to a file in Xcode, it may be a Source Control badge rather than a bad filename character.

In the terrain case, Git was still tracking bad hidden-character paths, which caused Xcode to keep showing a badge even though the actual file on disk had the correct clean filename. [cite:1271]

That means:

- Finder and the filesystem can be correct.
- Xcode can still look odd.
- Git status is the real source of truth for what Source Control thinks changed.

## Recovering after mistakes

If a commit was made at a good stopping point, it is always possible to get back to it. [cite:1269]

### Fast recovery to the last commit

`[bash] git restore .`

Optional cleanup of extra untracked files:

`[bash] git clean -fd`

### Recovery to a specific older checkpoint

`[bash] git log --oneline`

Find the desired commit ID, then:

`[bash] git reset --hard abcd123`

That returns the whole repo to that exact checkpoint. [cite:1269]

## Good beginner habits

A few habits make Git much less scary:

- Run `git status` often.
- Make a checkpoint commit whenever the project reaches a good stopping point.
- Do not panic if things break after a good commit exists.
- Use `git restore .` to undo tracked-file mistakes.
- Use `git clean -fd` only when certain untracked files are junk.

## What to remember most

If work is in a good state:

`[bash] git status`

`[bash] git add .`

`[bash] git commit -m "Checkpoint message"`

If things go sideways later:

`[bash] git restore .`

If a full rollback to a known checkpoint is needed:

`[bash] git log --oneline`

`[bash] git reset --hard COMMIT_ID`

That small set of commands is enough to work safely for now.
