cask "rsrsbar" do
  version "0.2.0"
  sha256 "1d1d5ff4dd57390ea3f077559a7eec7eb172fcbceacb674a52986426bdc8c632"

  url "https://github.com/nicecab/rsrsbar/releases/download/v#{version}/rsrsbar-v#{version}-aarch64-apple-darwin.zip"
  name "rsrsbar"
  desc "Menu bar manager for git-rsrs auto-sync watchers"
  homepage "https://github.com/nicecab/rsrsbar"

  depends_on arch: :arm64
  depends_on formula: "nicecab/tap/git-rsrs"
  depends_on macos: :sequoia

  app "rsrsbar.app"
  binary "#{appdir}/rsrsbar.app/Contents/MacOS/rsrsbar"

  # Unsigned (ad-hoc) app from our own tap: Homebrew quarantines the
  # download, and Gatekeeper would kill the app. Clear it while the app
  # is still staged, where the sandboxed steps may write.
  # Homebrew's sandbox refuses `launchctl bootstrap` and LaunchServices,
  # so no step can restart the app that `uninstall launchctl:` stops on
  # every upgrade; the caveats ask for `rsrsbar start` instead.
  preflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{staged_path}}/rsrsbar.app"]
  end

  uninstall launchctl: ["com.nicecab.rsrsbar.heartbeat", "com.nicecab.rsrsbar"]

  zap trash: [
    "~/Library/Application Support/rsrsbar",
    "~/Library/Caches/com.nicecab.rsrsbar",
    "~/Library/Logs/com.nicecab.rsrsbar.error.log",
    "~/Library/Logs/com.nicecab.rsrsbar.heartbeat.error.log",
    "~/Library/Logs/com.nicecab.rsrsbar.heartbeat.log",
    "~/Library/Logs/com.nicecab.rsrsbar.log",
  ]

  caveats <<~EOS
    Run `rsrsbar start` once to launch the menu bar app, then allow notifications.
    `brew upgrade` stops the app; run `rsrsbar start` again after each upgrade.
    Before uninstalling, run `rsrsbar remove <id>` for each registered repository;
    watchers left behind keep running without anyone to report their failures.
  EOS
end
