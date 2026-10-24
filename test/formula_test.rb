require "minitest/autorun"
require "tmpdir"
require "digest"
require "json"
require "fileutils"
require_relative "../lib/git_rsrs_formula"
require_relative "support/release_fixture"

class FormulaTest < Minitest::Test
  TARGETS = %w[aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl].freeze

  def setup
    @dir = Dir.mktmpdir("formula-test-")
    @release, @hashes = ReleaseFixture.create(@dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_renders_all_platform_urls_with_verified_checksums
    content = GitRsrsFormula.render(@release, @dir)
    assert_includes content, 'version "1.2.3"'
    TARGETS.each do |target|
      assert_includes content, "git-rsrs-v1.2.3-#{target}.tar.gz"
      assert_includes content, "sha256 \"#{@hashes[target]}\""
    end
    assert_includes content, '(checkout/"message.txt").write "updated\\n", 0'
    path = File.join(@dir, "formula.rb")
    File.write(path, content)
    assert system(RbConfig.ruby, "-c", path, out: File::NULL, err: File::NULL)
  end

  def test_checksum_mismatch_rejects_the_entire_update
    target = TARGETS.first
    File.write(File.join(@dir, "git-rsrs-v1.2.3-#{target}.tar.gz"), "tampered")
    assert_raises(ArgumentError) { GitRsrsFormula.render(@release, @dir) }
  end

  def test_missing_or_duplicated_assets_and_foreign_urls_are_rejected
    original = Marshal.load(Marshal.dump(@release))
    @release["assets"].pop
    assert_raises(ArgumentError) { GitRsrsFormula.render(@release, @dir) }
    @release = Marshal.load(Marshal.dump(original))
    @release["assets"] << @release["assets"].first.dup
    assert_raises(ArgumentError) { GitRsrsFormula.render(@release, @dir) }
    @release = original
    @release["assets"][0]["browser_download_url"] = "https://example.com/archive.tar.gz"
    assert_raises(ArgumentError) { GitRsrsFormula.render(@release, @dir) }
  end

  def test_unstable_tags_and_unpublished_releases_are_rejected
    ["v1.2.3-rc1", "v1.2.3\"\nsystem('bad')", "../bad", "main"].each do |tag|
      release = @release.merge("tag_name" => tag)
      assert_raises(ArgumentError) { GitRsrsFormula.render(release, @dir) }
    end
    %w[draft prerelease].each do |key|
      assert_raises(ArgumentError) { GitRsrsFormula.render(@release.merge(key => true), @dir) }
    end
  end

  def test_failed_update_keeps_existing_formula_and_rejects_downgrade
    path = File.join(@dir, "git-rsrs.rb")
    File.write(path, "class GitRsrs < Formula\n  version \"9.0.0\"\nend\n")
    before = File.binread(path)
    assert_raises(ArgumentError) { GitRsrsFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
    File.write(path, 'head "https://github.com/nicecab/git-rsrs.git", branch: "main"')
    GitRsrsFormula.write(@release, @dir, path)
    assert_includes File.read(path), 'version "1.2.3"'
    before = File.binread(path)
    File.write(File.join(@dir, "git-rsrs-v1.2.3-#{TARGETS.first}.tar.gz.sha256"), "bad checksum\n")
    assert_raises(ArgumentError) { GitRsrsFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end

  def test_same_version_cannot_silently_replace_published_checksums
    path = File.join(@dir, "git-rsrs.rb")
    GitRsrsFormula.write(@release, @dir, path)
    before = File.binread(path)
    name = "git-rsrs-v1.2.3-#{TARGETS.first}.tar.gz"
    File.write(File.join(@dir, name), "replacement")
    File.write(File.join(@dir, "#{name}.sha256"), "#{Digest::SHA256.hexdigest('replacement')}  #{name}\n")
    assert_raises(ArgumentError) { GitRsrsFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end
  def test_same_version_cannot_swap_platform_archives
    path = File.join(@dir, "git-rsrs.rb")
    GitRsrsFormula.write(@release, @dir, path)
    before = File.binread(path)
    intel, linux = TARGETS[1], TARGETS[2]
    intel_name = "git-rsrs-v1.2.3-#{intel}.tar.gz"
    linux_name = "git-rsrs-v1.2.3-#{linux}.tar.gz"
    old_intel = File.binread(File.join(@dir, intel_name))
    File.binwrite(File.join(@dir, intel_name), File.binread(File.join(@dir, linux_name)))
    File.binwrite(File.join(@dir, linux_name), old_intel)
    [intel_name, linux_name].each do |name|
      File.write(File.join(@dir, "#{name}.sha256"), "#{Digest::SHA256.file(File.join(@dir, name)).hexdigest}  #{name}\n")
    end
    @release["assets"].each do |asset|
      asset["digest"] = "sha256:#{Digest::SHA256.file(File.join(@dir, asset.fetch('name'))).hexdigest}"
    end
    assert_raises(ArgumentError) { GitRsrsFormula.write(@release, @dir, path) }
    assert_equal before, File.binread(path)
  end
end
