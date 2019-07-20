#!/usr/bin/env ruby
require 'pp'
require 'yaml'
require 'treetop'
require 'json'

require_relative '../lib/parser/cddl-util.rb'

Encoding.default_external = Encoding::UTF_8
require 'optparse'
require 'ostruct'

$options = OpenStruct.new
op = OptionParser.new do |opts|
  opts.banner = "Usage: kdrfc [options] file.md|file.mkd|file.xml"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    $options.verbose = v
  end
  opts.on("-r", "--[no-]remote", "Run xml2rfc remotely even if there is a local one") do |v|
    $options.remote = v
  end
  opts.on("-x", "--[no-]xml", "Convert to xml only") do |v|
    $options.xml_only = v
  end
end
op.parse!

case ARGV.size
when 1
  fn = ARGV[0]
else
  puts op
  exit 1
end

parser = CDDLParser.new
cddl_file = File.read(fn)
ast = parser.parse cddl_file
if ast
#  puts ast.to_yaml
  pp ast.ast
  puts ast.ast.to_yaml
else
  warn parser.failure_reason
  parser.failure_reason =~ /^(Expected .+) after/m
  warn "#{$1.gsub("\n", '<<<NEWLINE>>>')}:"
  warn cddl_file.lines.to_a[parser.failure_line - 1]
  warn "#{'~' * (parser.failure_column - 1)}^"
end
