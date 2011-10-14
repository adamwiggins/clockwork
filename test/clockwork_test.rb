require File.expand_path('../../lib/clockwork', __FILE__)
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
		assert_equal 1, Clockwork.tick(t).size
	end

	def assert_wont_run(t)
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

	test "once a day at 16:20" do
		Clockwork.every(1.day, 'myjob', :at => '16:20')

		assert_wont_run Time.parse('jan 1 2010 16:19:59')
		assert_will_run Time.parse('jan 1 2010 16:20:00')
		assert_wont_run Time.parse('jan 1 2010 16:20:01')
		assert_wont_run Time.parse('jan 2 2010 16:19:59')
		assert_will_run Time.parse('jan 2 2010 16:20:00')
	end

	test "twice a day at 16:20 and 18:10" do
		Clockwork.every(1.day, 'myjob', :at => ['16:20', '18:10'])

		assert_wont_run Time.parse('jan 1 2010 16:19:59')
		assert_will_run Time.parse('jan 1 2010 16:20:00')
		assert_wont_run Time.parse('jan 1 2010 16:20:01')

		assert_wont_run Time.parse('jan 1 2010 18:09:59')
		assert_will_run Time.parse('jan 1 2010 18:10:00')
		assert_wont_run Time.parse('jan 1 2010 18:10:01')
	end

	test "aborts when no handler defined" do
		Clockwork.clear!
		assert_raise(Clockwork::NoHandlerDefined) do
			Clockwork.every(1.minute, 'myjob')
		end
	end

	test "aborts when fails to parse" do
		assert_raise(Clockwork::FailedToParse) do
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
end
