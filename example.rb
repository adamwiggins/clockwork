require 'clockwork'
include Clockwork

every('10s') { puts 'every 10 secs' }
every('1m') { puts 'every minute' }
every('1h') { puts 'every hour' }

every('1d', :at => '00:00') { puts 'once a day at midnight' }
