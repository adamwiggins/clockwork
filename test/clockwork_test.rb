require File.dirname(__FILE__) + '/../lib/clockwork'
require 'contest'

class ClockworkTest < Test::Unit::TestCase
	setup do
		Clockwork.clear!
	end

	def assert_will_run(t)
		assert_equal 1, Clockwork.tick(t).size
	end

	def assert_wont_run(t)
		assert_equal 0, Clockwork.tick(t).size
	end

	test "once a minute" do
		Clockwork.every('1m') { }

		assert_will_run(t=Time.now)
		assert_wont_run(t+30)
		assert_will_run(t+60)
	end

	test "every three minutes" do
		Clockwork.every('3m') { }

		assert_will_run(t=Time.now)
		assert_wont_run(t+2*60)
		assert_will_run(t+3*60)
	end

	test "once an hour" do
		Clockwork.every('1h') { }

		assert_will_run(t=Time.now)
		assert_wont_run(t+30*60)
		assert_will_run(t+60*60)
	end

	test "once a day at 16:20" do
		Clockwork.every('1d', :at => '16:20') { }

		assert_wont_run Time.parse('jan 1 2010 16:19:59')
		assert_will_run Time.parse('jan 1 2010 16:20:00')
		assert_wont_run Time.parse('jan 1 2010 16:20:01')
		assert_wont_run Time.parse('jan 2 2010 16:19:59')
		assert_will_run Time.parse('jan 2 2010 16:20:00')
	end
end
