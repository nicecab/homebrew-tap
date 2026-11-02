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

  # Legacy flight blocks, not `*_steps`: steps run in Homebrew's sandbox
  # (HOME redirected, home unreadable) and their guards test only path
  # existence, so neither the launchctl probe nor `rsrsbar start` fits there.
  postflight do
    # Unsigned (ad-hoc) app from our own tap: Homebrew quarantines the
    # download, and Gatekeeper would kill the app. Clear it first.
    system_command("/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/rsrsbar.app"])
    marker = File.expand_path("~/Library/Caches/com.nicecab.rsrsbar/restart-after-upgrade")
    if File.exist?(marker)
      system_command("#{appdir}/rsrsbar.app/Contents/MacOS/rsrsbar", args: ["start"])
      File.delete(marker)
    end
  end

  # On upgrade this runs in the old version's cask, before `uninstall
  # launchctl:` boots the app out (Homebrew runs that on every upgrade).
  # It records whether the app was running so postflight can restart it.
  uninstall_preflight do
    marker = File.expand_path("~/Library/Caches/com.nicecab.rsrsbar/restart-after-upgrade")
    FileUtils.rm(marker, force: true)
    loaded = system_command("/bin/launchctl",
                            args:         ["print", "gui/#{Process.uid}/com.nicecab.rsrsbar"],
                            must_succeed: false, print_stderr: false).success?
    if loaded
      FileUtils.mkdir_p(File.dirname(marker))
      File.write(marker, "")
    end
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
    Before uninstalling, run `rsrsbar remove <id>` for each registered repository;
    watchers left behind keep running without anyone to report their failures.
  EOS
end
