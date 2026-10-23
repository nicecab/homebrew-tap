require "fileutils"
require_relative "support/release_fixture"
require_relative "../lib/git_rsrs_formula"

abort "usage: render_example.rb OUTPUT_DIRECTORY" unless ARGV.length == 1
FileUtils.mkdir_p(ARGV[0])
release, = ReleaseFixture.create(ARGV[0])
destination = File.join(ARGV[0], "git-rsrs.rb")
GitRsrsFormula.write(release, ARGV[0], destination)
puts destination
