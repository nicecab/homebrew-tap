require "json"
require_relative "../lib/git_rsrs_formula"

abort "usage: render_formula.rb RELEASE_JSON ASSET_DIRECTORY DESTINATION" unless ARGV.length == 3
begin
  changed = GitRsrsFormula.write(JSON.parse(File.read(ARGV[0])), ARGV[1], ARGV[2])
  puts changed ? "Updated #{ARGV[2]}" : "Formula is already current"
rescue ArgumentError, KeyError, JSON::ParserError, SystemCallError => error
  warn error.message
  exit 1
end
