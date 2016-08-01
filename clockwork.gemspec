Gem::Specification.new do |s|
  s.name = "clockwork"
  s.version = "2.0.0"

  s.authors = ["Adam Wiggins", "tomykaira"]
  s.license = 'MIT'
  s.description = "A scheduler process to replace cron, using a more flexible Ruby syntax running as a single long-running process.  Inspired by rufus-scheduler and resque-scheduler."
  s.email = ["adam@heroku.com", "tomykaira@gmail.com"]
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.homepage = "http://github.com/tomykaira/clockwork"
  s.summary = "A scheduler process to replace cron."

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency(%q<tzinfo>)
  s.add_dependency(%q<activesupport>)

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "daemons"
  s.add_development_dependency "minitest", "~> 5.8"
  s.add_development_dependency "mocha"
end
