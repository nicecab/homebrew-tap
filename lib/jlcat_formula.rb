require "digest"
require "fileutils"
require "rubygems/version"
require "tempfile"

module JlcatFormula
  REPOSITORY = "nicecab/jlcat".freeze
  TARGETS = %w[aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl].freeze

  def self.render(release, directory)
    tag = release.fetch("tag_name")
    raise ArgumentError, "expected a stable vMAJOR.MINOR.PATCH tag" unless /\Av\d+\.\d+\.\d+\z/.match?(tag)
    raise ArgumentError, "release is not published and stable" if release["draft"] || release["prerelease"]

    version = tag.delete_prefix("v")
    assets = release.fetch("assets")
    hashes = TARGETS.to_h do |target|
      name = "jlcat-#{tag}-#{target}.tar.gz"
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
      class Jlcat < Formula
        desc "JSON/JSONL table viewer with auto-flattening and TUI support"
        homepage "https://github.com/#{REPOSITORY}"
        version "#{version}"
        license "MIT"

        on_macos do
          on_arm do
            url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/jlcat-#{tag}-aarch64-apple-darwin.tar.gz"
            sha256 "#{hashes.fetch('aarch64-apple-darwin')}"
          end
          on_intel do
            url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/jlcat-#{tag}-x86_64-apple-darwin.tar.gz"
            sha256 "#{hashes.fetch('x86_64-apple-darwin')}"
          end
        end

        on_linux do
          depends_on arch: :x86_64
          on_intel do
            url "https://github.com/#{REPOSITORY}/releases/download/#{tag}/jlcat-#{tag}-x86_64-unknown-linux-musl.tar.gz"
            sha256 "#{hashes.fetch('x86_64-unknown-linux-musl')}"
          end
        end

        def install
          bin.install "jlcat"
        end

        test do
          assert_match "jlcat #{version}", shell_output("\#{bin}/jlcat --version")
          assert_match "Alice", pipe_output("\#{bin}/jlcat", "{\\"name\\":\\"Alice\\"}\\n", 0)
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
        if new_version == old_version
          associations = lambda do |formula|
            formula.scan(/^\s*url "([^"]+)"\s+sha256 "([a-f0-9]{64})"$/).to_h
          end
          unless associations.call(previous) == associations.call(content)
            raise ArgumentError, "published platform checksums changed without a version increase"
          end
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
