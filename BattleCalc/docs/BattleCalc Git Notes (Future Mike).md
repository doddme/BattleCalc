# BattleCalc Git Notes (Future Mike)

This is a quick reminder of how to use Git for BattleCalc so you don’t have to remember every detail.

## Branches

- **main**: Stable baseline will be the approved Apple App once we have users testing
- **dev**: Active development.
- **qa**: Testing branch, goes to Apple with a new branch once sent
- **ancients-integration-checkpoint**: THIS IS WHAT WAS SUBMITTED TO Apple Appstore TestFlight


## Everyday workflow in Xcode

1. Make your changes in Xcode.
2. Commit:
   - Menu: `Source Control` → `Commit…`
   - Select files.
   - Enter a short, clear message.
   - Click `Commit`.
3. Push:
   - Menu: `Source Control` → `Push…`
   - Or click the “cloud with up arrow” icon if visible.

Xcode will push the **current branch** (dev, qa, etc.) to `origin` (GitHub).

## Everyday workflow in Terminal

From the repo root:

```bash
cd /Users/mikedodd/Documents/BattleCalc

git status          # see what changed
git add -A          # stage all changes
git commit -m "Short, clear message"  # commit
git push            # push current branch to origin



If Git asks for a password
•	Username:  doddme 
•	Password: your classic GitHub personal access token (PAT) with  repo  scope.
If  git push  says  Everything up-to-date , it means your branch is already in sync with GitHub.
```

## Editing EXISTING files only then
```bash
git commit -a -m "message"
```


## Editing NEW and EXISTING files then
```bash
git add -A
git commit -m "Short, clear message"
```

## Checking branches
```bash
cd /Users/mikedodd/Documents/BattleCalc

git branch          # list local branches
git status          # shows current branch at top
```


## Safety reminder
•	**Before doing anything risky** (like big refactors), make sure:  

•	 **`git status`**  shows  working tree clean.  
•	 **`git push`**  says  Everything up-to-date .   

That means your work is safely backed up on GitHub.


