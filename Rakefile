task :default => :build

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

