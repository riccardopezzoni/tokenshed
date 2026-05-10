# Signing And Notarization

TokenShed is distributed outside the Mac App Store. Public app releases should be Developer ID signed and notarized before publishing the DMG.

The CLI can be distributed through Homebrew separately, but the app DMG should follow this flow:

```text
build app -> sign app -> create DMG -> sign DMG -> notarize DMG -> staple DMG
```

## Requirements

1. Apple Developer Program membership.
2. A `Developer ID Application` certificate in your login keychain.
3. A notarytool keychain profile.

Check available signing identities:

```bash
security find-identity -v -p codesigning
```

The identity should look like:

```text
Developer ID Application: Your Name (TEAMID)
```

## Notary Profile

Create a notary profile in Keychain:

```bash
xcrun notarytool store-credentials tokenshed-notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID"
```

`notarytool` will prompt for an app-specific password and store it in Keychain. Do not commit or paste notarization passwords into shell scripts.

You can also use App Store Connect API key credentials with `notarytool` if preferred.

## Build A Signed Release

```bash
export TOKSHED_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export TOKSHED_NOTARY_PROFILE="tokenshed-notary"
scripts/build-signed-release.sh
```

If `TOKSHED_NOTARY_PROFILE` is omitted, the script signs the app and DMG but skips notarization.

Release outputs:

```text
Build/TokenShed-1.0.0.dmg
Build/TokenShed-1.0.0-macos.zip
Build/tokenshed-1.0.0-macos-arm64.tar.gz
Build/tokenshed-1.0.0-macos-arm64.tar.gz.sha256
```

## Polished DMG Layout

The release script uses DMGMaker when it is available next to this repository:

```bash
git clone https://github.com/saihgupr/DMGMaker.git ../DMGMaker
```

You can also set `DMGMAKER_DIR` to a custom checkout path. If DMGMaker is not available, `scripts/build-dmg.sh` falls back to a plain `hdiutil` DMG.
