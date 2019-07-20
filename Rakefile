task :default => :build

task :build => "lib/parser/cddl.rb" do
  sh "gem build cddlc.gemspec"
end

file "lib/parser/cddl.rb" => "lib/parser/cddl.treetop" do
  sh 'LANG="en_US.utf-8" tt lib/parser/cddl.treetop'
end

file "lib/parser/cddl.treetop" => "lib/parser/cddl.abnftt" do
  sh "abnftt lib/parser/cddl.abnftt"
  sh "diff lib/parser/cddl.abnf lib/parser/cddl.abnf.orig"
end

