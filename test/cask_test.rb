require "minitest/autorun"
require "tmpdir"
require "digest"
require "fileutils"
require_relative "../lib/rsrsbar_cask"
require_relative "support/cask_release_fixture"

class CaskTest < Minitest::Test
  ZIP = "rsrsbar-v1.2.3-aarch64-apple-darwin.zip".freeze
  MARKER = '~/Library/Caches/com.nicecab.rsrsbar/restart-after-upgrade'.freeze

  def setup
    @dir = Dir.mktmpdir("cask-test-")
    @release, @sha256 = CaskReleaseFixture.create(@dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def deep_copy(release)
    Marshal.load(Marshal.dump(release))
  end

  def test_renders_url_and_verified_checksum
    content = RsrsbarCask.render(@release, @dir)
    assert_includes content, 'cask "rsrsbar" do'
    assert_includes content, 'version "1.2.3"'
    assert_includes content, 'url "https://github.com/nicecab/rsrsbar/releases/download/v#{version}/rsrsbar-v#{version}-aarch64-apple-darwin.zip"'
    assert_includes content, "sha256 \"#{@sha256}\""
    path = File.join(@dir, "cask.rb")
    File.write(path, content)
    assert system(RbConfig.ruby, "-c", path, out: File::NULL, err: File::NULL)
  end

  def test_checksum_mismatch_rejects_update
    File.write(File.join(@dir, ZIP), "tampered")
    assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
    File.write(File.join(@dir, "#{ZIP}.sha256"), "not a checksum\n")
    assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
  end

  def test_missing_duplicated_or_foreign_assets_rejected
    original = deep_copy(@release)
    @release["assets"].pop
    assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
    @release = deep_copy(original)
    @release["assets"] << @release["assets"].first.dup
    assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
    @release = deep_copy(original)
    @release["assets"][0]["browser_download_url"] = "https://example.com/#{ZIP}"
    assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
    # A second archive or checksum is a changed release layout, not something to pick from.
    ["rsrsbar-v1.2.3-x86_64-apple-darwin.zip", "rsrsbar-v1.2.3-x86_64-apple-darwin.zip.sha256"].each do |extra|
      @release = deep_copy(original)
      @release["assets"] << { "name" => extra, "browser_download_url" => "https://github.com/nicecab/rsrsbar/releases/download/v1.2.3/#{extra}" }
      assert_raises(ArgumentError) { RsrsbarCask.render(@release, @dir) }
    end
    # Assets of other kinds (release notes, SBOMs) are tolerated so they cannot stall the updater.
    @release = original
    @release["assets"] << { "name" => "sbom.spdx.json", "browser_download_url" => "https://github.com/nicecab/rsrsbar/releases/download/v1.2.3/sbom.spdx.json" }
    assert_includes RsrsbarCask.render(@release, @dir), "sha256 \"#{@sha256}\""
  end

  def test_unstable_or_draft_release_rejected
    ["v1.2.3-rc1", "v1.2.3\"\nsystem('bad')", "../bad", "main"].each do |tag|
      assert_raises(ArgumentError) { RsrsbarCask.render(@release.merge("tag_name" => tag), @dir) }
    end
    %w[draft prerelease].each do |key|
      assert_raises(ArgumentError) { RsrsbarCask.render(@release.merge(key => true), @dir) }
    end
  end

  def test_github_digest_mismatch_rejected
    @release["assets"].each { |asset| asset["digest"] = "sha256:#{Digest::SHA256.file(File.join(@dir, asset['name'])).hexdigest}" }
    assert_includes RsrsbarCask.render(@release, @dir), "sha256 \"#{@sha256}\""
    @release["assets"].each_index do |index|
      release = deep_copy(@release)
      release["assets"][index]["digest"] = "sha256:#{'0' * 64}"
      assert_raises(ArgumentError) { RsrsbarCask.render(release, @dir) }
    end
  end

  def test_downgrade_refused
    path = File.join(@dir, "rsrsbar.rb")
    File.write(path, "cask \"rsrsbar\" do\n  version \"9.0.0\"\nend\n")
    before = File.binread(path)
    assert_raises(ArgumentError) { RsrsbarCask.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_same_version_checksum_change_refused
    path = File.join(@dir, "rsrsbar.rb")
    assert RsrsbarCask.write(@release, @dir, path)
    before = File.binread(path)
    File.write(File.join(@dir, ZIP), "replacement")
    File.write(File.join(@dir, "#{ZIP}.sha256"), "#{Digest::SHA256.hexdigest('replacement')}  #{ZIP}\n")
    assert_raises(ArgumentError) { RsrsbarCask.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_unchanged_release_is_a_no_op
    path = File.join(@dir, "rsrsbar.rb")
    assert RsrsbarCask.write(@release, @dir, path)
    before = File.binread(path)
    refute RsrsbarCask.write(@release, @dir, path)
    assert_equal before, File.binread(path)
  end

  def test_failed_write_keeps_previous_file
    path = File.join(@dir, "rsrsbar.rb")
    File.write(path, 'cask "rsrsbar" do; version "0.1.0"; end')
    assert RsrsbarCask.write(@release, @dir, path)
    assert_includes File.read(path), 'version "1.2.3"'
    before = File.binread(path)
    File.write(File.join(@dir, "#{ZIP}.sha256"), "bad checksum\n")
    assert_raises(ArgumentError) { RsrsbarCask.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_uninstall_lists_exact_labels
    content = RsrsbarCask.render(@release, @dir)
    lines = content.lines.grep(/^\s*uninstall /)
    assert_equal 1, lines.length
    assert_equal 'uninstall launchctl: ["com.nicecab.rsrsbar.heartbeat", "com.nicecab.rsrsbar"]', lines[0].strip
    refute_includes lines[0], "*"
  end

  def test_postflight_restarts_only_a_loaded_app
    content = RsrsbarCask.render(@release, @dir)
    postflight = content[/^  postflight do\n.*?^  end\n/m]
    preflight = content[/^  uninstall_preflight do\n.*?^  end\n/m]
    refute_nil postflight
    refute_nil preflight
    assert_operator content.index(postflight), :<, content.index(preflight)

    # The old version's uninstall_preflight probes the app job and leaves a marker only when it is loaded.
    assert_includes preflight, 'system_command("/bin/launchctl"'
    assert_includes preflight, '["print", "gui/#{Process.uid}/com.nicecab.rsrsbar"]'
    assert_includes preflight, "marker = File.expand_path(\"#{MARKER}\")"
    assert_match(/\.success\?\n\s+if loaded\n\s+FileUtils\.mkdir_p\(File\.dirname\(marker\)\)\n\s+File\.write\(marker, ""\)\n\s+end/, preflight)

    # postflight: strip quarantine first, start only behind the marker guard, then remove the marker.
    quarantine = postflight.index('system_command("/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/rsrsbar.app"])')
    guard = postflight.index("if File.exist?(marker)")
    start = postflight.index('system_command("#{appdir}/rsrsbar.app/Contents/MacOS/rsrsbar", args: ["start"])')
    refute_nil quarantine
    refute_nil guard
    refute_nil start
    assert_operator quarantine, :<, guard
    assert_operator guard, :<, start
    assert_includes postflight, "marker = File.expand_path(\"#{MARKER}\")"
    assert_match(/if File\.exist\?\(marker\)\n\s+system_command\(.*args: \["start"\]\)\n\s+File\.delete\(marker\)\n\s+end/, postflight)
    refute_includes postflight, "launchctl"
  end
end
