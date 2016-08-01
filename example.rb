require 'clockwork'

module Clockwork
  handler do |job|
    puts "Queueing job: #{job}"
  end

  every(10.seconds, 'run.me.every.10.seconds')
  every(1.minute, 'run.me.every.minute')
  every(1.hour, 'run.me.every.hour')

  every(1.day, 'run.me.at.midnight', :at => '00:00')

  every(1.day, 'custom.event.handler', :at => '00:30') do
    puts 'This event has its own handler'
  end

  # note: callbacks that return nil or false will cause event to not run
  on(:before_tick) do
    puts "tick"
    true
  end

  on(:after_tick) do
    puts "tock"
    true
  end
end
