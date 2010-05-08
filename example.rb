require 'lib/clepsydra'
include Clepsydra

every('2s') { puts 'every 2 secs' }
every('4s') { puts 'every 4 secs' }

run
