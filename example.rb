require 'lib/clepsydra'
include Clepsydra

every('10s') { puts 'every 10 secs' }
every('1m') { puts 'every minute' }
every('1h') { puts 'every hour' }

run
