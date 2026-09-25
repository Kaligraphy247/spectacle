#!/bin/zsh
# Build Spectacle, replace /Applications/Spectacle.app with the new build, and relaunch it.
set -euo pipefail

cd "${0:A:h}"

local_config=Configurations/Signing.local.xcconfig
if [[ ! -f $local_config ]]; then
  # The ID in the certificate's name is a member ID; the team ID is the certificate subject's OU.
  hash=$(security find-identity -v -p codesigning | awk '/"Apple Development: /{print $2; exit}')
  team=""
  if [[ -n $hash ]]; then
    team=$(security find-certificate -a -c "Apple Development" -Z -p \
      | awk -v h="$hash" '/^SHA-1 hash:/{on=($3==h)} on && !/^SHA-(1|256) hash:/' \
      | openssl x509 -noout -subject | sed -nE 's/.*OU=([A-Z0-9]{10}).*/\1/p')
  fi
  if [[ -n $team ]]; then
    printf 'CODE_SIGN_STYLE = Manual\nCODE_SIGN_IDENTITY = Apple Development\nDEVELOPMENT_TEAM = %s\n' "$team" > $local_config
    echo "Created $local_config (team $team)."
  else
    echo "No Apple Development certificate found; building ad-hoc signed." >&2
    echo "Accessibility permission will need re-granting after every build." >&2
  fi
fi

xcodebuild -project Spectacle.xcodeproj -target Spectacle -configuration Release SYMROOT="$PWD/build" build -quiet

if pgrep -x Spectacle > /dev/null; then
  pkill -x Spectacle
  for _ in {1..10}; do
    pgrep -x Spectacle > /dev/null || break
    sleep 0.5
  done
fi

rm -rf /Applications/Spectacle.app
ditto build/Release/Spectacle.app /Applications/Spectacle.app
codesign --verify --deep /Applications/Spectacle.app
open /Applications/Spectacle.app

echo "Installed $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' /Applications/Spectacle.app/Contents/Info.plist)"
signature=$(codesign -dvv /Applications/Spectacle.app 2>&1)
grep -m1 "^Authority=" <<< "$signature" || echo "Signature: ad-hoc"
