require 'jeweler'

Jeweler::Tasks.new do |s|
  s.name = "clockwork"
  s.summary = "A scheduler process to replace cron."
  s.description = "A scheduler process to replace cron, using a more flexible Ruby syntax running as a single long-running process.  Inspired by rufus-scheduler and resque-scheduler."
  s.author = "Adam Wiggins"
  s.email = "adam@heroku.com"
  s.homepage = "http://github.com/adamwiggins/clockwork"
  s.executables = [ "clockwork" ]
  s.rubyforge_project = "clockwork"

  s.files = FileList["[A-Z]*", "{bin,lib}/**/*"]
  s.test_files = FileList["{test}/**/*"]
end

Jeweler::GemcutterTasks.new

task 'test' do
  sh "ruby test/clockwork_test.rb"
end

task :build => :test
task :default => :test
