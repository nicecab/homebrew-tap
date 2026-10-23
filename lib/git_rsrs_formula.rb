require "digest"
require "fileutils"
require "rubygems/version"
require "tempfile"

module GitRsrsFormula
  REPOSITORY = "nicecab/git-rsrs".freeze
  TARGETS = %w[aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl].freeze

  def self.render(release, directory)
    tag = release.fetch("tag_name")
    raise ArgumentError, "expected a stable vMAJOR.MINOR.PATCH tag" unless /\Av\d+\.\d+\.\d+\z/.match?(tag)
    raise ArgumentError, "release is not published and stable" if release["draft"] || release["prerelease"]

    version = tag.delete_prefix("v")
    assets = release.fetch("assets")
    hashes = TARGETS.to_h do |target|
      name = "git-rsrs-#{tag}-#{target}.tar.gz"
      [name, "#{name}.sha256"].each do |asset_name|
        matches = assets.select { |asset| asset["name"] == asset_name }
        raise ArgumentError, "missing or duplicated asset: #{asset_name}" unless matches.length == 1
        expected_url = "https://github.com/#{REPOSITORY}/releases/download/#{tag}/#{asset_name}"
        raise ArgumentError, "unexpected asset URL" unless matches[0]["browser_download_url"] == expected_url
        digest = matches[0]["digest"]
        if digest && digest != "sha256:#{Digest::SHA256.file(File.join(directory, asset_name)).hexdigest}"
          raise ArgumentError, "GitHub asset digest mismatch: #{asset_name}"
        end
      end
      checksum = File.read(File.join(directory, "#{name}.sha256"))
      match = /\A([a-f0-9]{64})[ \t]+\*?#{Regexp.escape(name)}\n?\z/.match(checksum)
      raise ArgumentError, "malformed checksum file: #{name}" unless match
      actual = Digest::SHA256.file(File.join(directory, name)).hexdigest
      raise ArgumentError, "archive checksum mismatch: #{name}" unless actual == match[1]
      [target, actual]
    end

    <<~RUBY
      class GitRsrs < Formula
        desc "Synchronize Git repositories with external command hooks"
        homepage "https://github.com/#{REPOSITORY}"
        version "#{version}"

        depends_on "git"

        on_macos do
          on_arm do
            url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/git-rsrs-#{tag}-aarch64-apple-darwin.tar.gz"
            sha256 "#{hashes.fetch('aarch64-apple-darwin')}"
          end
          on_intel do
            url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/git-rsrs-#{tag}-x86_64-apple-darwin.tar.gz"
            sha256 "#{hashes.fetch('x86_64-apple-darwin')}"
          end
        end

        on_linux do
          url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/git-rsrs-#{tag}-x86_64-unknown-linux-musl.tar.gz"
          sha256 "#{hashes.fetch('x86_64-unknown-linux-musl')}"
          depends_on arch: :x86_64
        end

        def install
          bin.install "git-rsrs"
          pkgshare.install "examples" if (buildpath/"examples").exist?
        end

        test do
          assert_match "git-rsrs #{version}", shell_output("\#{bin}/git-rsrs --version")
          origin = testpath/"origin.git"
          checkout = testpath/"checkout"
          system "git", "init", "--bare", origin
          system "git", "init", "-b", "main", checkout
          system "git", "-C", checkout, "config", "user.name", "Homebrew Test"
          system "git", "-C", checkout, "config", "user.email", "test@example.invalid"
          system "git", "-C", checkout, "config", "core.hooksPath", "/dev/null"
          system "git", "-C", checkout, "remote", "add", "origin", origin
          (checkout/"message.txt").write "initial\\n"
          system "git", "-C", checkout, "add", "-A"
          system "git", "-C", checkout, "-c", "commit.gpgsign=false", "commit", "-m", "initial"
          system "git", "-C", checkout, "push", "-u", "origin", "main"
          (testpath/"config.toml").write "version = 1\\nbranch = 'main'\\n"
          (checkout/"message.txt").write "updated\\n"
          system bin/"git-rsrs", "--repo", checkout, "--config", testpath/"config.toml", "sync"
          assert_equal "updated\\n", shell_output("git --git-dir=\#{origin} show main:message.txt")
        end
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
        raise ArgumentError, "refusing a formula downgrade" if Gem::Version.new(new_version) < Gem::Version.new(old_version)
        if new_version == old_version && previous.scan(/sha256 "([a-f0-9]{64})"/).sort != content.scan(/sha256 "([a-f0-9]{64})"/).sort
          raise ArgumentError, "published checksums changed without a version increase"
        end
      end
      return false if previous == content
    end
    FileUtils.mkdir_p(File.dirname(destination))
    Tempfile.create([".formula-", ".rb"], File.dirname(destination)) do |file|
      file.write(content)
      file.flush
      file.fsync
      file.chmod(0o644)
      File.rename(file.path, destination)
    end
    true
  end
end
