require "digest"
require "fileutils"
require "rubygems/version"
require "tempfile"

module RsrsbarCask
  REPOSITORY = "nicecab/rsrsbar".freeze
  TARGET = "aarch64-apple-darwin".freeze

  def self.render(release, directory)
    tag = release.fetch("tag_name")
    raise ArgumentError, "expected a stable vMAJOR.MINOR.PATCH tag" unless /\Av\d+\.\d+\.\d+\z/.match?(tag)
    raise ArgumentError, "release is not published and stable" if release["draft"] || release["prerelease"]

    version = tag.delete_prefix("v")
    assets = release.fetch("assets")
    name = "rsrsbar-#{tag}-#{TARGET}.zip"
    expected = [name, "#{name}.sha256"]
    expected.each do |asset_name|
      matches = assets.select { |asset| asset["name"] == asset_name }
      raise ArgumentError, "missing or duplicated asset: #{asset_name}" unless matches.length == 1
      expected_url = "https://github.com/#{REPOSITORY}/releases/download/#{tag}/#{asset_name}"
      raise ArgumentError, "unexpected asset URL" unless matches[0]["browser_download_url"] == expected_url
      digest = matches[0]["digest"]
      if digest && digest != "sha256:#{Digest::SHA256.file(File.join(directory, asset_name)).hexdigest}"
        raise ArgumentError, "GitHub asset digest mismatch: #{asset_name}"
      end
    end
    extras = assets.map { |asset| asset["name"] }.grep(/\.(zip|sha256)\z/) - expected
    raise ArgumentError, "unexpected archive or checksum asset: #{extras.join(', ')}" unless extras.empty?
    checksum = File.read(File.join(directory, "#{name}.sha256"))
    match = /\A([a-f0-9]{64})[ \t]+\*?#{Regexp.escape(name)}\n?\z/.match(checksum)
    raise ArgumentError, "malformed checksum file: #{name}" unless match
    sha256 = Digest::SHA256.file(File.join(directory, name)).hexdigest
    raise ArgumentError, "archive checksum mismatch: #{name}" unless sha256 == match[1]

    <<~RUBY
      cask "rsrsbar" do
        version "#{version}"
        sha256 "#{sha256}"

        url "https://github.com/#{REPOSITORY}/releases/download/v\#{version}/rsrsbar-v\#{version}-#{TARGET}.zip"
        name "rsrsbar"
        desc "Menu bar manager for git-rsrs auto-sync watchers"
        homepage "https://github.com/#{REPOSITORY}"

        depends_on arch: :arm64
        depends_on formula: "nicecab/tap/git-rsrs"
        depends_on macos: :sequoia

        app "rsrsbar.app"
        binary "\#{appdir}/rsrsbar.app/Contents/MacOS/rsrsbar"

        # Legacy flight blocks, not `*_steps`: steps run in Homebrew's sandbox
        # (HOME redirected, home unreadable) and their guards test only path
        # existence, so neither the launchctl probe nor `rsrsbar start` fits there.
        postflight do
          # Unsigned (ad-hoc) app from our own tap: Homebrew quarantines the
          # download, and Gatekeeper would kill the app. Clear it first.
          system_command("/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "\#{appdir}/rsrsbar.app"])
          marker = File.expand_path("~/Library/Caches/com.nicecab.rsrsbar/restart-after-upgrade")
          if File.exist?(marker)
            system_command("\#{appdir}/rsrsbar.app/Contents/MacOS/rsrsbar", args: ["start"])
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
                                  args:         ["print", "gui/\#{Process.uid}/com.nicecab.rsrsbar"],
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
    RUBY
  end

  def self.write(release, directory, destination)
    content = render(release, directory)
    if File.exist?(destination)
      previous = File.read(destination)
      old_version = previous[/^\s*version "([0-9.]+)"$/, 1]
      new_version = release.fetch("tag_name").delete_prefix("v")
      if old_version
        raise ArgumentError, "refusing a cask downgrade" if Gem::Version.new(new_version) < Gem::Version.new(old_version)
        checksum_of = ->(cask) { cask[/^\s*sha256 "([a-f0-9]{64})"$/, 1] }
        if new_version == old_version && checksum_of.call(previous) != checksum_of.call(content)
          raise ArgumentError, "published checksum changed without a version increase"
        end
      end
      return false if previous == content
    end
    FileUtils.mkdir_p(File.dirname(destination))
    Tempfile.create([".cask-", ".rb"], File.dirname(destination)) do |file|
      file.write(content)
      file.flush
      file.fsync
      file.chmod(0o644)
      File.rename(file.path, destination)
    end
    true
  end
end
