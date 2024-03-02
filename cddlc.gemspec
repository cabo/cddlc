Gem::Specification.new do |s|
  s.name = "cddlc"
  s.version = "0.3.1"
  s.summary = "CDDL (Concise Data Definition Language) converters and miscellaneous tools"
  s.description = %q{cddlc implements converters and miscellaneous tools for CDDL, RFC 8610}
  s.author = "Carsten Bormann"
  s.email = "cabo@tzi.org"
  s.license = "MIT"
  s.homepage = "http://github.com/cabo/cddlc"
  s.files = Dir['lib/**/*.rb'] + %w(cddlc.gemspec) + Dir['data/*.cddl'] + Dir['bin/**/*.rb']
  s.executables = Dir['bin/*'].map {|x| File.basename(x)}
  s.required_ruby_version = '>= 1.9.2'

  s.require_paths = ["lib"]

  s.add_development_dependency 'bundler', '~>1'
  s.add_dependency 'treetop', '~>1'
  s.add_dependency 'json', '~>2'
  s.add_dependency 'neatjson', '~>0.10'
end
