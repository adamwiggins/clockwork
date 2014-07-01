require File.expand_path('../../lib/clockwork', __FILE__)
require 'clockwork/manager_with_database_tasks'
require 'rubygems'
require 'contest'
require 'mocha/setup'
require 'time'
require 'active_support/time'

class ManagerWithDatabaseTasksTest < Test::Unit::TestCase

  class ScheduledTask; end
  class ScheduledTaskType2; end

  setup do
    @manager = Clockwork::ManagerWithDatabaseTasks.new
    class << @manager
      def log(msg); end
    end
    @manager.handler { }
  end

  def assert_will_run(t)
    if t.is_a? String
      t = Time.parse(t)
    end
    assert_equal 1, @manager.tick(t).size
  end

  def assert_wont_run(t)
    if t.is_a? String
      t = Time.parse(t)
    end
    assert_equal 0, @manager.tick(t).size
  end

  def tick_at(now = Time.now, options = {})
    seconds_to_tick_for = options[:and_every_second_for] || 0
    number_of_ticks = seconds_to_tick_for + 1 # add one for right now
    number_of_ticks.times{|i| @manager.tick(now + i) }
  end

  def next_minute(now = Time.now)
    Time.new(now.year, now.month, now.day, now.hour, now.min + 1, 0)
  end

  describe "sync_database_tasks" do

    describe "arguments" do

      def test_does_not_raise_error_with_valid_arguments
        @manager.sync_database_tasks(model: ScheduledTask, every: 1.minute) {}
      end

      def test_raises_argument_error_if_param_called_model_is_not_set
        assert_raises ArgumentError do
          @manager.sync_database_tasks(model: ScheduledTask) {}
        end
      end

      def test_raises_argument_error_if_param_called_every_is_not_set
        assert_raises ArgumentError do
          @manager.sync_database_tasks(every: 1.minute) {}
        end
      end

      def test_raises_argument_error_if_param_called_every_is_less_than_1_minute
        assert_raises ArgumentError do
          @manager.sync_database_tasks(model: ScheduledTask, every: 59.seconds) {}
        end
      end
    end

    context "when database reload frequency is greater than task frequency period" do
      setup do
        @tasks_run = []
        @scheduled_task1 = stub(:frequency => 10, :name => 'ScheduledTask:1', :at => nil, :id => 1)
        @scheduled_task2 = stub(:frequency => 10, :name => 'ScheduledTask:2', :at => nil, :id => 2)
        @scheduled_task1_modified = stub(:frequency => 5, :name => 'ScheduledTaskModified:1', :at => nil, :id => 3)
        ScheduledTask.stubs(:all).returns([@scheduled_task1])

        @database_reload_frequency = 1.minute

        @now = Time.now

        # setup the database sync
        @manager.sync_database_tasks model: ScheduledTask, every: @database_reload_frequency do |job_name|
          @tasks_run << job_name
        end
      end

      def test_fetches_and_registers_database_task
        tick_at(@now, :and_every_second_for => 1.second)
        assert_equal ["ScheduledTask:1"], @tasks_run
      end

      def test_multiple_database_tasks_can_be_registered
        ScheduledTask.stubs(:all).returns([@scheduled_task1, @scheduled_task2])
        tick_at(@now, :and_every_second_for => 1.second)
        assert_equal ["ScheduledTask:1", "ScheduledTask:2"], @tasks_run
      end

      def test_database_task_does_not_run_again_before_frequency_specified_in_database
        tick_at(@now, :and_every_second_for => @scheduled_task1.frequency - 1.second) # runs at 1
        assert_equal 1, @tasks_run.length
      end

      def test_database_task_runs_repeatedly_with_frequency_specified_in_database
        tick_at(@now, :and_every_second_for => (2 * @scheduled_task1.frequency) + 1.second) # runs at 1, 11, and 21
        assert_equal 3, @tasks_run.length
      end

      def test_reloads_tasks_from_database
        ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task2])
        tick_at(@now, :and_every_second_for => @database_reload_frequency.seconds)
        @manager.tick # @scheduled_task2 should run immediately on next tick (then every 10 seconds)

        assert_equal [
          "ScheduledTask:1",
          "ScheduledTask:1",
          "ScheduledTask:1",
          "ScheduledTask:1",
          "ScheduledTask:1",
          "ScheduledTask:1",
          "ScheduledTask:2"], @tasks_run
      end

      def test_reloaded_tasks_run_repeatedly
        ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task2])
        tick_at(@now, :and_every_second_for => @database_reload_frequency.seconds + 11.seconds)
        assert_equal ["ScheduledTask:2", "ScheduledTask:2"], @tasks_run[-2..-1]
      end

      def test_reloading_task_with_modified_frequency_will_run_with_new_frequency
        ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task1_modified])

        tick_at(@now, :and_every_second_for => 66.seconds)

        # task1 runs at: 1, 11, 21, 31, 41, 51 (6 runs)
        # database tasks are reloaded at: 60
        # task1_modified runs at: 61 (next tick after reload) and then 66 (2 runs)
        assert_equal 8, @tasks_run.length
      end

      def test_stops_running_deleted_database_task
        ScheduledTask.stubs(:all).returns([@scheduled_task1], [])
        tick_at(@now, :and_every_second_for => @database_reload_frequency.seconds)
        before = @tasks_run.dup

        # tick through reload, and run for enough ticks that previous task would have run
        tick_at(@now + @database_reload_frequency.seconds + 20.seconds)
        after = @tasks_run

        assert_equal before, after
      end

      def test_task_with_edited_name_switches_to_new_name
        tick_at @now, :and_every_second_for => @database_reload_frequency.seconds - 1.second
        @tasks_run = [] # clear tasks run before change

        modified_task_1 = stub(:frequency => 30, :name => 'ScheduledTask:1_modified', :at => nil, :id => 1)
        ScheduledTask.stubs(:all).returns([modified_task_1])
        tick_at @now + @database_reload_frequency.seconds, :and_every_second_for => @database_reload_frequency.seconds - 1.seconds

        assert_equal ["ScheduledTask:1_modified", "ScheduledTask:1_modified"], @tasks_run
      end

      def test_task_with_edited_frequency_switches_to_new_frequency
        tick_at @now, :and_every_second_for => @database_reload_frequency.seconds - 1.second
        @tasks_run = [] # clear tasks run before change

        modified_task_1 = stub(:frequency => 30, :name => 'ScheduledTask:1', :at => nil, :id => 1)
        ScheduledTask.stubs(:all).returns([modified_task_1])
        tick_at @now + @database_reload_frequency.seconds, :and_every_second_for => @database_reload_frequency.seconds - 1.seconds

        assert_equal 2, @tasks_run.length
      end

      def test_task_with_edited_at_runs_at_new_at
        task_1 = stub(:frequency => 1.day, :name => 'ScheduledTask:1', :at => '10:30', :id => 1)
        ScheduledTask.stubs(:all).returns([task_1])

        assert_will_run 'jan 1 2010 10:30:00'
        assert_wont_run 'jan 1 2010 09:30:00'
        tick_at @now, :and_every_second_for => @database_reload_frequency.seconds - 1.second

        modified_task_1 = stub(:frequency => 1.day, :name => 'ScheduledTask:1', :at => '09:30', :id => 1)
        ScheduledTask.stubs(:all).returns([modified_task_1])
        tick_at @now + @database_reload_frequency.seconds, :and_every_second_for => @database_reload_frequency.seconds - 1.seconds

        assert_will_run 'jan 1 2010 09:30:00'
        assert_wont_run 'jan 1 2010 10:30:00'
      end

      def test_daily_task_with_at_should_only_run_once
        next_minute = next_minute(@now)
        at = next_minute.strftime('%H:%M')
        @scheduled_task_with_at = stub(:frequency => 1.day, :name => 'ScheduledTaskWithAt:1', :at => at, :id => 5)
        ScheduledTask.stubs(:all).returns([@scheduled_task_with_at])

        # tick from now, though specified :at time
        tick_at(@now, :and_every_second_for => (2 * @database_reload_frequency.seconds) + 1.second)

        assert_equal 1, @tasks_run.length
      end

      def test_comma_separated_at_from_task_leads_to_multiple_event_ats
        task = stub(:frequency => 1.day, :name => 'ScheduledTask:1', :at => '16:20, 18:10', :id => 1)
        ScheduledTask.stubs(:all).returns([task])

        tick_at @now, :and_every_second_for => @database_reload_frequency.seconds

        assert_wont_run 'jan 1 2010 16:19:59'
        assert_will_run 'jan 1 2010 16:20:00'
        assert_wont_run 'jan 1 2010 16:20:01'

        assert_wont_run 'jan 1 2010 18:09:59'
        assert_will_run 'jan 1 2010 18:10:00'
        assert_wont_run 'jan 1 2010 18:10:01'
      end

      def test_having_multiple_sync_database_tasks_will_work
        ScheduledTask.stubs(:all).returns([@scheduled_task1])

        # setup 2nd database sync
        @scheduled_task_type2 = stub(:frequency => 10, :name => 'ScheduledTaskType2:1', :at => nil, :id => 6)

        ScheduledTaskType2.stubs(:all).returns([@scheduled_task_type2])
        @manager.sync_database_tasks model: ScheduledTaskType2, every: @database_reload_frequency do |job_name|
          @tasks_run << job_name
        end

        tick_at(@now, :and_every_second_for => 1.second)

        assert_equal ["ScheduledTask:1", "ScheduledTaskType2:1"], @tasks_run
      end
    end

    context "when database reload frequency is less than task frequency period" do
      setup do
        @tasks_run = []
        @scheduled_task1 = stub(:frequency => 5.minutes, :name => 'ScheduledTask:1', :at => nil, :id => 1)
        @scheduled_task2 = stub(:frequency => 10, :name => 'ScheduledTask:2', :at => nil, :id => 2)
        @scheduled_task1_modified = stub(:frequency => 5, :name => 'ScheduledTaskModified:1', :at => nil)
        ScheduledTask.stubs(:all).returns([@scheduled_task1])

        @database_reload_frequency = 1.minute

        @now = Time.now
        @next_minute = next_minute(@now) # database sync task only happens on minute boundary

        # setup the database sync
        @manager.sync_database_tasks model: ScheduledTask, every: @database_reload_frequency do |job_name|
          @tasks_run << job_name
        end
      end

      def test_it_only_runs_the_task_once_within_the_task_frequency_period
        tick_at(@now, :and_every_second_for => 5.minutes)
        assert_equal 1, @tasks_run.length
      end
    end

    context "with task with :at as empty string" do
      setup do
        @task_with_empty_string_at = stub(:frequency => 10, :name => 'ScheduledTask:1', :at => '', :id => 1)
        ScheduledTask.stubs(:all).returns([@task_with_empty_string_at])

        @tasks_run = []

        @manager.sync_database_tasks(model: ScheduledTask, every: 1.minute) do |job_name|
          @tasks_run << job_name
        end
      end

      def test_it_does_not_raise_an_error
        begin
          tick_at(Time.now, :and_every_second_for => 10.seconds)
        rescue => e
          assert false, "Raised an error: #{e.message}"
        end
      end

      def test_it_runs_the_task
        begin
          tick_at(Time.now, :and_every_second_for => 10.seconds)
        rescue => e
        end
        assert_equal 1, @tasks_run.length
      end
    end
  end
end
