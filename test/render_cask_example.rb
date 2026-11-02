require "fileutils"
require_relative "support/cask_release_fixture"
require_relative "../lib/rsrsbar_cask"

abort "usage: render_cask_example.rb OUTPUT_DIRECTORY" unless ARGV.length == 1
FileUtils.mkdir_p(ARGV[0])
release, = CaskReleaseFixture.create(ARGV[0])
destination = File.join(ARGV[0], "rsrsbar.rb")
RsrsbarCask.write(release, ARGV[0], destination)
puts destination
