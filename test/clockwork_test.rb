require File.expand_path('../../lib/clockwork', __FILE__)
require 'rubygems'
require 'contest'
require 'mocha'
require 'time'

module Clockwork
  def log(msg)
  end
end

class ClockworkTest < Test::Unit::TestCase
  setup do
    Clockwork.clear!
    Clockwork.handler { }
  end

  def assert_will_run(t)
    if t.is_a? String
      t = Time.parse(t)
    end
    assert_equal 1, Clockwork.tick(t).size
  end

  def assert_wont_run(t)
    if t.is_a? String
      t = Time.parse(t)
    end
    assert_equal 0, Clockwork.tick(t).size
  end

  test "once a minute" do
    Clockwork.every(1.minute, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+30)
    assert_will_run(t+60)
  end

  test "every three minutes" do
    Clockwork.every(3.minutes, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+2*60)
    assert_will_run(t+3*60)
  end

  test "once an hour" do
    Clockwork.every(1.hour, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+30*60)
    assert_will_run(t+60*60)
  end

  test "once a week" do
    Clockwork.every(1.week, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+60*60*24*6)
    assert_will_run(t+60*60*24*7)
  end

  test "once a day at 16:20" do
    Clockwork.every(1.day, 'myjob', :at => '16:20')

    assert_wont_run 'jan 1 2010 16:19:59'
    assert_will_run 'jan 1 2010 16:20:00'
    assert_wont_run 'jan 1 2010 16:20:01'
    assert_wont_run 'jan 2 2010 16:19:59'
    assert_will_run 'jan 2 2010 16:20:00'
  end

  test ":at also accepts 8:20" do
    Clockwork.every(1.hour, 'myjob', :at => '8:20')

    assert_wont_run 'jan 1 2010 08:19:59'
    assert_will_run 'jan 1 2010 08:20:00'
    assert_wont_run 'jan 1 2010 08:20:01'
  end

  test "twice a day at 16:20 and 18:10" do
    Clockwork.every(1.day, 'myjob', :at => ['16:20', '18:10'])

    assert_wont_run 'jan 1 2010 16:19:59'
    assert_will_run 'jan 1 2010 16:20:00'
    assert_wont_run 'jan 1 2010 16:20:01'

    assert_wont_run 'jan 1 2010 18:09:59'
    assert_will_run 'jan 1 2010 18:10:00'
    assert_wont_run 'jan 1 2010 18:10:01'
  end

  test "once an hour at **:20" do
    Clockwork.every(1.hour, 'myjob', :at => '**:20')

    assert_wont_run 'jan 1 2010 15:19:59'
    assert_will_run 'jan 1 2010 15:20:00'
    assert_wont_run 'jan 1 2010 15:20:01'
    assert_wont_run 'jan 2 2010 16:19:59'
    assert_will_run 'jan 2 2010 16:20:00'
  end

  test ":at also accepts *:20" do
    Clockwork.every(1.hour, 'myjob', :at => '*:20')

    assert_wont_run 'jan 1 2010 15:19:59'
    assert_will_run 'jan 1 2010 15:20:00'
    assert_wont_run 'jan 1 2010 15:20:01'
  end

  test "on every Saturday" do
    Clockwork.every(1.week, 'myjob', :at => 'Saturday 12:00')

    assert_wont_run 'jan 1 2010 12:00:00'
    assert_will_run 'jan 2 2010 12:00:00' # Saturday
    assert_wont_run 'jan 3 2010 12:00:00'
    assert_wont_run 'jan 8 2010 12:00:00'
    assert_will_run 'jan 9 2010 12:00:00'
  end

  test ":at accepts abbreviated weekday" do
    Clockwork.every(1.week, 'myjob', :at => 'sat 12:00')

    assert_wont_run 'jan 1 2010 12:00:00'
    assert_will_run 'jan 2 2010 12:00:00' # Saturday
    assert_wont_run 'jan 3 2010 12:00:00'
  end

  test "aborts when no handler defined" do
    Clockwork.clear!
    assert_raise(Clockwork::NoHandlerDefined) do
      Clockwork.every(1.minute, 'myjob')
    end
  end

  test "aborts when fails to parse" do
    assert_raise(Clockwork::At::FailedToParse) do
      Clockwork.every(1.day, "myjob", :at => "a:bc")
    end
  end

  test "general handler" do
    $set_me = 0
    Clockwork.handler { $set_me = 1 }
    Clockwork.every(1.minute, 'myjob')
    Clockwork.tick(Time.now)
    assert_equal 1, $set_me
  end

  test "event-specific handler" do
    $set_me = 0
    Clockwork.every(1.minute, 'myjob') { $set_me = 2 }
    Clockwork.tick(Time.now)
    assert_equal 2, $set_me
  end

  test "exceptions are trapped and logged" do
    Clockwork.handler { raise 'boom' }
    event = Clockwork.every(1.minute, 'myjob')
    event.expects(:log_error)
    assert_nothing_raised { Clockwork.tick(Time.now) }
  end

  test "exceptions still set the last timestamp to avoid spastic error loops" do
    Clockwork.handler { raise 'boom' }
    event = Clockwork.every(1.minute, 'myjob')
    event.stubs(:log_error)
    Clockwork.tick(t = Time.now)
    assert_equal t, event.last
  end

  test "should be configurable" do
    Clockwork.configure do |config|
      config[:sleep_timeout] = 200
      config[:logger] = "A Logger"
    end

    assert_equal 200, Clockwork.config[:sleep_timeout]
    assert_equal "A Logger", Clockwork.config[:logger]
  end

  test "configuration should have reasonable defaults" do
    assert_equal 1, Clockwork.config[:sleep_timeout]
    assert Clockwork.config[:logger].is_a?(Logger)
  end

  test "should be able to specify a different timezone than local" do
    Clockwork.every(1.day, 'myjob', :at => '10:00', :tz => 'UTC')

    assert_wont_run 'jan 1 2010 10:00:00 EST'
    assert_will_run 'jan 1 2010 10:00:00 UTC'
  end

  test "should be able to specify a different timezone than local for multiple times" do
    Clockwork.every(1.day, 'myjob', :at => ['10:00', '8:00'], :tz => 'UTC')

    assert_wont_run 'jan 1 2010 08:00:00 EST'
    assert_will_run 'jan 1 2010 08:00:00 UTC'
    assert_wont_run 'jan 1 2010 10:00:00 EST'
    assert_will_run 'jan 1 2010 10:00:00 UTC'
  end

  test "should be able to configure a default timezone to use for all events" do
    Clockwork.configure { |config| config[:tz] = 'UTC' }
    Clockwork.every(1.day, 'myjob', :at => '10:00')

    assert_wont_run 'jan 1 2010 10:00:00 EST'
    assert_will_run 'jan 1 2010 10:00:00 UTC'
  end

  test "should be able to override a default timezone in an event" do
    Clockwork.configure { |config| config[:tz] = 'UTC' }
    Clockwork.every(1.day, 'myjob', :at => '10:00', :tz => 'EST')

    assert_will_run 'jan 1 2010 10:00:00 EST'
    assert_wont_run 'jan 1 2010 10:00:00 UTC'
  end

  test ":if true then always run" do
    Clockwork.every(1.second, 'myjob', :if => lambda { |_| true })

    assert_will_run 'jan 1 2010 16:20:00'
  end

  test ":if false then never run" do
    Clockwork.every(1.second, 'myjob', :if => lambda { |_| false })

    assert_wont_run 'jan 1 2010 16:20:00'
  end

  test ":if the first day of month" do
    Clockwork.every(1.second, 'myjob', :if => lambda { |t| t.day == 1 })

    assert_will_run 'jan 1 2010 16:20:00'
    assert_wont_run 'jan 2 2010 16:20:00'
    assert_will_run 'feb 1 2010 16:20:00'
  end

  test ":if is not callable then raise ArgumentError" do
    assert_raise(ArgumentError) do
      Clockwork.every(1.second, 'myjob', :if => true)
    end
  end

end
