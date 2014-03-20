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

    setup do
      @tasks_run = []
      @scheduled_task1 = stub(:frequency => 10, :name => 'ScheduledTask:1', :at => nil)
      @scheduled_task2 = stub(:frequency => 10, :name => 'ScheduledTask:2', :at => nil)
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

    def test_does_not_fetch_database_tasks_until_next_minute
      seconds_upto_and_including_next_minute = (@next_minute - @now).seconds.to_i + 1
      tick_at(@now, :and_every_second_for => seconds_upto_and_including_next_minute)
      assert_equal [], @tasks_run
    end

    def test_fetches_and_registers_database_task
      tick_at(@next_minute, :and_every_second_for => 1.second)
      assert_equal ["ScheduledTask:1"], @tasks_run
    end

    def test_multiple_database_tasks_can_be_registered
      ScheduledTask.stubs(:all).returns([@scheduled_task1, @scheduled_task2])
      tick_at(@next_minute, :and_every_second_for => 1.second)
      assert_equal ["ScheduledTask:1", "ScheduledTask:2"], @tasks_run
    end

    def test_database_task_does_not_run_again_before_frequency_specified_in_database
      tick_at(@next_minute, :and_every_second_for => 9.seconds) # runs at 1
      assert_equal 1, @tasks_run.length
    end

    def test_database_task_runs_repeatedly_with_frequency_specified_in_database
      tick_at(@next_minute, :and_every_second_for => 21.seconds) # runs at 1, 11, and 21
      assert_equal 3, @tasks_run.length
    end

    def test_reloads_tasks_from_database
      ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task2])
      tick_at(@next_minute, :and_every_second_for => @database_reload_frequency.seconds)
      @manager.tick # @scheduled_task2 should run immediately on next tick (then every 10 seconds)

      assert_equal "ScheduledTask:2", @tasks_run.last
    end

    def test_reloaded_tasks_run_repeatedly
      ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task2])
      tick_at(@next_minute, :and_every_second_for => @database_reload_frequency.seconds + 11.seconds)
      assert_equal ["ScheduledTask:2", "ScheduledTask:2"], @tasks_run[-2..-1]
    end

    def test_stops_running_deleted_database_task
      ScheduledTask.stubs(:all).returns([@scheduled_task1], [])
      tick_at(@next_minute, :and_every_second_for => @database_reload_frequency.seconds)
      before = @tasks_run.dup

      # tick through reload, and run for enough ticks that previous task would have run
      tick_at(@next_minute + @database_reload_frequency.seconds + 20.seconds)
      after = @tasks_run

      assert_equal before, after
    end

    def test_reloading_task_with_modified_frequency_will_run_with_new_frequency
      ScheduledTask.stubs(:all).returns([@scheduled_task1], [@scheduled_task1_modified])

      tick_at(@next_minute, :and_every_second_for => 66.seconds)

      # task1 runs at: 1, 11, 21, 31, 41, 51 (6 runs)
      # database tasks are reloaded at: 60
      # task1_modified runs at: 61 (next tick after reload) and then 66 (2 runs)
      assert_equal 8, @tasks_run.length
    end

    # Catch a bug caused by allowing database tasks to be run in the same clock cycle that the database
    # sync occurs. When this happens, a previously scheduled database task will be scheduled to run,
    # we then fetch the same task afresh (wiping out the @events_from_database object), but the
    # previously scheduled task still runs because #task `events` variable already stored it *before*
    # we wiped out the @events_from_database objects.
    #
    # We have a situation like this:
    #
    # 12:31:00    #tick loops through events to run
    #               sync_database_tasks_for_model_ task is run
    #                 fetches database task 1 with :at => 12:32, and schedules it to run (object task 1')
    #
    # ...
    #
    # 12:32:00    #tick loops through events that should be run, of which task 1' is included
    #               sync_database_tasks_for_model_ task is run
    #                 fetches database task 1 with :at => 12:32, and schedules it to run (object task 1'')
    #               task 1' is run
    #
    # 12:32:01    #tick loops through events that should be run, of which task 1'' is included
    #               task 1'' is run
    def test_daily_task_with_at_should_not_run_twice_when_already_scheduled
      minute_after_next = next_minute(@next_minute)
      at = minute_after_next.strftime('%H:%M')
      @scheduled_task_with_at = stub(:frequency => 1.day, :name => 'ScheduledTaskWithAt:1', :at => at)
      ScheduledTask.stubs(:all).returns([@scheduled_task_with_at])

      # tick from now, though specified :at time
      tick_at(@now, :and_every_second_for => (2 * @database_reload_frequency.seconds) + 1.second)

      assert_equal 1, @tasks_run.length
    end

    def test_having_multiple_sync_database_tasks_will_work
      ScheduledTask.stubs(:all).returns([@scheduled_task1])

      # setup 2nd database sync
      @scheduled_task_type2 = stub(:frequency => 10, :name => 'ScheduledTaskType2:1', :at => nil)

      ScheduledTaskType2.stubs(:all).returns([@scheduled_task_type2])
      @manager.sync_database_tasks model: ScheduledTaskType2, every: @database_reload_frequency do |job_name|
        @tasks_run << job_name
      end

      tick_at(@next_minute, :and_every_second_for => 1.second)

      assert_equal ["ScheduledTask:1", "ScheduledTaskType2:1"], @tasks_run
    end
  end
end
