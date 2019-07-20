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
  opts.banner = "Usage: cddlc.rb [options] file.cddl"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    $options.verbose = v
  end
  opts.on("-tFMT", "--to=FMT", "Target format") do |v|
    $options.target = v
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
  result = ast.ast
  case $options.target
  when "json"
    pp result
  when "neat", nil
    require 'neatjson'
    puts JSON.neat_generate(result, after_comma: 1, after_colon: 1)
  when "yaml"
    puts result.to_yaml
  else
    warn ["Unknown target format: ", $options.target].inspect
    
  end
else
  warn parser.failure_reason
  parser.failure_reason =~ /^(Expected .+) after/m
  warn "#{$1.gsub("\n", '<<<NEWLINE>>>')}:"
  warn cddl_file.lines.to_a[parser.failure_line - 1]
  warn "#{'~' * (parser.failure_column - 1)}^"
end
