require 'clockwork'
include Clockwork

handler do |job|
  puts "Queueing job: #{job}"
end

every(10.seconds, 'run.me.every.10.seconds')
every(1.minute, 'run.me.every.minute')
every(1.hour, 'run.me.every.hour')

every(1.day, 'run.me.at.midnight', :at => '00:00')

every(1.day, 'custom.event.handler', :at => '00:30') do
  puts "This event has its own handler"
end
