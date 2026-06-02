# Homebrew Cask for Prayer Times (spec §7.8, §13).
#
# Place this in a tap repo (e.g. github.com/<you>/homebrew-tap as
# Casks/prayer-times.rb), then users install with:
#   brew install --cask <you>/tap/prayer-times
#
# The release workflow prints the version + sha256 to plug in here (or automate
# the bump with a PAT — see RELEASING.md). Sparkle and Homebrew coexist: both
# install the same notarized artifact.
cask "prayer-times" do
  version "0.1.0"
  sha256 "46db2db80fa983a64b4eeb8f63a2d03428fff2eba70a64722a0446705b040212"

  url "https://github.com/tareq1988/prayer-times-macos/releases/download/v#{version}/PrayerTimes-#{version}.zip"
  name "Prayer Times"
  desc "Menu bar app for Islamic prayer times"
  homepage "https://github.com/tareq1988/prayer-times-macos"

  # Sparkle handles in-app updates; let Homebrew defer to it.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Prayer Times.app"

  caveats <<~EOS
    This build is ad-hoc signed (not yet notarized). If macOS blocks it, either
    install with --no-quarantine:
      brew install --cask --no-quarantine #{token}
    or remove the quarantine attribute after install:
      xattr -dr com.apple.quarantine "/Applications/Prayer Times.app"
  EOS

  zap trash: [
    "~/Library/Preferences/com.wedevs.prayertimes.plist",
    "~/Library/Caches/com.wedevs.prayertimes",
  ]
end
