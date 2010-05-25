require 'clockwork'
include Clockwork

handler do |job|
	puts "Running job: #{job}"
end

every('10s', 'run.me.every.10.seconds')
every('1m', 'run.me.every.minute')
every('1h', 'run.me.every.hour')

every('1d', 'run.me.at.midnight', :at => '00:00')
