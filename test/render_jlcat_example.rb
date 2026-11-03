require "fileutils"
require_relative "support/jlcat_release_fixture"
require_relative "../lib/jlcat_formula"

abort "usage: render_jlcat_example.rb OUTPUT_DIRECTORY" unless ARGV.length == 1
FileUtils.mkdir_p(ARGV[0])
release, = JlcatReleaseFixture.create(ARGV[0])
destination = File.join(ARGV[0], "jlcat.rb")
JlcatFormula.write(release, ARGV[0], destination)
puts destination
