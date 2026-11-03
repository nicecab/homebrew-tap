require "minitest/autorun"
require "tmpdir"
require "digest"
require "json"
require "fileutils"
require_relative "../lib/jlcat_formula"
require_relative "support/jlcat_release_fixture"

class JlcatFormulaTest < Minitest::Test
  TARGETS = %w[aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl].freeze

  def setup
    @dir = Dir.mktmpdir("jlcat-formula-test-")
    @release, @hashes = JlcatReleaseFixture.create(@dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_renders_all_platform_urls_with_verified_checksums
    content = JlcatFormula.render(@release, @dir)
    assert_includes content, 'version "1.2.3"'
    TARGETS.each do |target|
      assert_includes content, "jlcat-v1.2.3-#{target}.tar.gz"
      assert_includes content, "sha256 \"#{@hashes[target]}\""
    end
    assert_includes content, 'assert_match "jlcat 1.2.3", shell_output("#{bin}/jlcat --version")'
    path = File.join(@dir, "formula.rb")
    File.write(path, content)
    assert system(RbConfig.ruby, "-c", path, out: File::NULL, err: File::NULL)
  end

  def test_checksum_mismatch_rejects_the_entire_update
    target = TARGETS.first
    File.write(File.join(@dir, "jlcat-v1.2.3-#{target}.tar.gz"), "tampered")
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
  end

  def test_checksum_lines_must_name_the_bare_archive
    name = "jlcat-v1.2.3-#{TARGETS.first}.tar.gz"
    File.write(File.join(@dir, "#{name}.sha256"), "#{@hashes[TARGETS.first]}  dist/#{name}\n")
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
  end

  def test_missing_or_duplicated_assets_and_foreign_urls_are_rejected
    original = Marshal.load(Marshal.dump(@release))
    @release["assets"].pop
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
    @release = Marshal.load(Marshal.dump(original))
    @release["assets"] << @release["assets"].first.dup
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
    @release = original
    @release["assets"][0]["browser_download_url"] = "https://example.com/archive.tar.gz"
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
  end

  def test_github_asset_digest_mismatch_is_rejected
    @release["assets"][0]["digest"] = "sha256:#{'0' * 64}"
    assert_raises(ArgumentError) { JlcatFormula.render(@release, @dir) }
  end

  def test_unstable_tags_and_unpublished_releases_are_rejected
    ["v1.2.3-rc1", "v1.2.3\"\nsystem('bad')", "../bad", "main"].each do |tag|
      release = @release.merge("tag_name" => tag)
      assert_raises(ArgumentError) { JlcatFormula.render(release, @dir) }
    end
    %w[draft prerelease].each do |key|
      assert_raises(ArgumentError) { JlcatFormula.render(@release.merge(key => true), @dir) }
    end
  end

  def test_failed_update_keeps_existing_formula_and_rejects_downgrade
    path = File.join(@dir, "jlcat.rb")
    File.write(path, "class Jlcat < Formula\n  version \"9.0.0\"\nend\n")
    before = File.binread(path)
    assert_raises(ArgumentError) { JlcatFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
    File.write(path, "class Jlcat < Formula\n  version \"1.0.0\"\nend\n")
    assert JlcatFormula.write(@release, @dir, path)
    assert_includes File.read(path), 'version "1.2.3"'
    refute JlcatFormula.write(@release, @dir, path)
    before = File.binread(path)
    File.write(File.join(@dir, "jlcat-v1.2.3-#{TARGETS.first}.tar.gz.sha256"), "bad checksum\n")
    assert_raises(ArgumentError) { JlcatFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_same_version_cannot_silently_replace_published_checksums
    path = File.join(@dir, "jlcat.rb")
    JlcatFormula.write(@release, @dir, path)
    before = File.binread(path)
    name = "jlcat-v1.2.3-#{TARGETS.first}.tar.gz"
    File.write(File.join(@dir, name), "replacement")
    File.write(File.join(@dir, "#{name}.sha256"), "#{Digest::SHA256.hexdigest('replacement')}  #{name}\n")
    assert_raises(ArgumentError) { JlcatFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_same_version_cannot_swap_platform_archives
    path = File.join(@dir, "jlcat.rb")
    JlcatFormula.write(@release, @dir, path)
    before = File.binread(path)
    intel, linux = TARGETS[1], TARGETS[2]
    intel_name = "jlcat-v1.2.3-#{intel}.tar.gz"
    linux_name = "jlcat-v1.2.3-#{linux}.tar.gz"
    old_intel = File.binread(File.join(@dir, intel_name))
    File.binwrite(File.join(@dir, intel_name), File.binread(File.join(@dir, linux_name)))
    File.binwrite(File.join(@dir, linux_name), old_intel)
    [intel_name, linux_name].each do |name|
      File.write(File.join(@dir, "#{name}.sha256"), "#{Digest::SHA256.file(File.join(@dir, name)).hexdigest}  #{name}\n")
    end
    @release["assets"].each do |asset|
      asset["digest"] = "sha256:#{Digest::SHA256.file(File.join(@dir, asset.fetch('name'))).hexdigest}"
    end
    assert_raises(ArgumentError) { JlcatFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end
end
