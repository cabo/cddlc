task :default => :build

task :i => "lib/parser/cddlgrammar.rb" do
  sh "time gebuin cddlc.gemspec"
end

task :build => "lib/parser/cddlgrammar.rb" do
  sh "gem build cddlc.gemspec"
end

file "lib/parser/cddlgrammar.rb" => "lib/parser/cddlgrammar.treetop" do
  sh 'LANG="en_US.utf-8" tt lib/parser/cddlgrammar.treetop'
end

file "lib/parser/cddlgrammar.treetop" => "lib/parser/cddlgrammar.abnftt" do
  sh "abnftt lib/parser/cddlgrammar.abnftt"
  sh "diff lib/parser/cddlgrammar.abnf lib/parser/cddl.abnf.orig"
end

task :test do
  files = Dir["test/*.cddl"].map {|fn| [fn, File.stat(fn).mtime]}.sort_by{|fn, mtime| -mtime.to_i}
  files.each do |fn, _mtime|
    sh "CDDLC_DEBUG= cddlc --test #{fn}"
  end
end

task :testlog do
  files = Dir["test/*.cddl"]
  files.each do |fn|
    sh "CDDLC_DEBUG= cddlc --test #{fn}"
  end
end
