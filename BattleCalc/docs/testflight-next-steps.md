# TestFlight next steps for DiceCalc

This note is a short local checklist for uploading the next build and getting it to testers.

## Should local changes be committed?

Yes. The current Git status shows two modified files:

- `BattleCalc.xcodeproj/project.pbxproj`
- `BattleCalc/App/GameSelectionView.swift`

Those changes include app identity and UI text updates, so they should be committed once the app is working the way you want.

Suggested commit flow:

```bash
git status
git add BattleCalc.xcodeproj/project.pbxproj BattleCalc/App/GameSelectionView.swift
git commit -m "Prepare DiceCalc for TestFlight"
```

## Main Apple links

- App Store Connect: <https://appstoreconnect.apple.com/apps>
- TestFlight overview: <https://developer.apple.com/testflight/>
- Upload builds help: <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/>
- Add internal testers: <https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/>
- Invite external testers: <https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/>

## Xcode checks before upload

1. Open the project in Xcode.
2. Select the app target.
3. Confirm these values:
   - Display Name: `DiceCalc`
   - Bundle Identifier: `com.mikedodd.dicecalc`
   - Version: `1.0` or the version you want to ship
   - Build: increment this every time, for example `3`, `4`, `5`
4. Open **Signing & Capabilities**.
5. Make sure the correct Team is selected and automatic signing is enabled.

## Upload a new build

1. In Xcode, choose a generic device target such as **Any iOS Device (arm64)**.
2. From the menu bar, choose **Product > Archive**.
3. When Organizer opens, select the newest archive.
4. Click **Distribute App**.
5. Choose **App Store Connect**.
6. Choose **Upload**.
7. Follow the prompts and finish the upload.

## Find the uploaded build

1. Open App Store Connect.
2. Go to **Apps**.
3. Open the app record: **DiceCalculator2026**.
4. Click the **TestFlight** tab.
5. Wait for the new build to finish processing.

## Internal testers

Internal testers are App Store Connect users on the team.

1. In **TestFlight**, look under **Internal Testing**.
2. Add the build to the internal group if needed.
3. Internal testers can usually see the build as soon as it is ready.

## External testers

External testers are friends or other people who are not on the App Store Connect team.

1. In **TestFlight**, create or open an **External Testing** group.
2. Open the uploaded build under **Builds**.
3. Add the external group to that build.
4. Fill out **Test Information** if Apple asks for it.
   - What to Test: short explanation of what the tester should check
   - Feedback Email: your email
   - Contact Information: your name, phone, and email
   - Sign-In Information: if the app has no login, use `no-login-required` if Apple forces those fields
5. Submit the build for external beta review.
6. After Apple approves it, the build becomes available to the external group.

## Every new build

For each new tester build, repeat this sequence:

1. Make changes in Xcode.
2. Increase the **Build** number.
3. Archive.
4. Upload.
5. Wait for processing in **TestFlight**.
6. Add the build to the tester group if needed.
7. For external testers, submit for beta review if Apple requires it.

## Common reminders

- The App Store Connect app name can differ from the on-device app name.
- The bundle identifier must match between Xcode and App Store Connect.
- Internal testers see builds sooner than external testers.
- External testing usually needs beta review before the build becomes available.
- If a build does not show up, wait for processing to finish and refresh the TestFlight page.
