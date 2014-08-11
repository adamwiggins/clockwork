require 'contest'
require 'mocha/setup'
require 'time'
require 'active_support/time'

require_relative '../../lib/clockwork'
require_relative '../../lib/clockwork/database_events'
require_relative 'test_helpers'

module DatabaseEvents

  class SyncPerformerTest < Test::Unit::TestCase

    setup do
      @now = Time.now
      DatabaseEventModelClass.delete_all
      DatabaseEventModelClass2.delete_all

      Clockwork.manager = @manager = Clockwork::DatabaseEvents::Manager.new
      class << @manager
        def log(msg); end # silence log output
      end
    end

    describe "setup" do
      setup do
        @subject = Clockwork::DatabaseEvents::SyncPerformer
      end

      describe "arguments" do
        def test_does_not_raise_error_with_valid_arguments
          @subject.setup(model: DatabaseEventModelClass, every: 1.minute) {}
        end

        def test_raises_argument_error_if_model_is_not_set
          error = assert_raises KeyError do
            @subject.setup(every: 1.minute) {}
          end
          assert_equal error.message, ":model must be set to the model class"
        end

        def test_raises_argument_error_if_every_is_not_set
          error = assert_raises KeyError do
            @subject.setup(model: DatabaseEventModelClass) {}
          end
          assert_equal error.message, ":every must be set to the database sync frequency"
        end
      end

      context "when database reload frequency is greater than model frequency period" do
        setup do
          @events_run = []
          @sync_frequency = 1.minute
        end

        def test_fetches_and_registers_event_from_database
          DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 1.second)
          
          assert_equal ["DatabaseEventModelClass:1"], @events_run
        end

        def test_multiple_events_from_database_can_be_registered
          DatabaseEventModelClass.create(:frequency => 10)
          DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 1.second)

          assert_equal ["DatabaseEventModelClass:1", "DatabaseEventModelClass:2"], @events_run
        end

        def test_event_from_database_does_not_run_again_before_frequency_specified_in_database
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => model.frequency - 1.second)
          assert_equal 1, @events_run.length
        end

        def test_event_from_database_runs_repeatedly_with_frequency_specified_in_database
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => (2 * model.frequency) + 1.second)

          assert_equal 3, @events_run.length
        end

        def test_reloaded_events_from_database_run_repeatedly
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => @sync_frequency - 1)

          model.update(:name => "DatabaseEventModelClass:1:Reloaded")

          tick_at(@now + @sync_frequency, :and_every_second_for => model.frequency * 2)

          assert_equal ["DatabaseEventModelClass:1:Reloaded", "DatabaseEventModelClass:1:Reloaded"], @events_run[-2..-1]
        end

        def test_reloading_events_from_database_with_modified_frequency_will_run_with_new_frequency
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => @sync_frequency - 1.second)
          model.update(:frequency => 5)
          tick_at(@now + @sync_frequency, :and_every_second_for => 6.seconds)

          # model runs at: 1, 11, 21, 31, 41, 51 (6 runs)
          # database sync happens at: 60
          # modified model runs at: 61 (next tick after reload) and then 66 (2 runs)
          assert_equal 8, @events_run.length
        end

        def test_stops_running_deleted_events_from_database
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => (@sync_frequency - 1.second))
          before = @events_run.dup
          model.delete!
          tick_at(@now + @sync_frequency, :and_every_second_for => @sync_frequency)
          after = @events_run

          assert_equal before, after
        end

        def test_event_from_database_with_edited_name_switches_to_new_name
          model = DatabaseEventModelClass.create(:frequency => 10.seconds)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at @now, :and_every_second_for => @sync_frequency - 1.second
          @events_run.clear
          model.update(:name => "DatabaseEventModelClass:1_modified")
          tick_at @now + @sync_frequency, :and_every_second_for => (model.frequency * 2)

          assert_equal ["DatabaseEventModelClass:1_modified", "DatabaseEventModelClass:1_modified"], @events_run
        end

        def test_event_from_database_with_edited_frequency_switches_to_new_frequency
          model = DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at @now, :and_every_second_for => @sync_frequency - 1.second
          @events_run.clear
          model.update(:frequency => 30)
          tick_at @now + @sync_frequency, :and_every_second_for => @sync_frequency - 1.seconds

          assert_equal 2, @events_run.length
        end

        def test_event_from_database_with_edited_at_runs_at_new_at
          model = DatabaseEventModelClass.create(:frequency => 1.day, :at => '10:30')
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          assert_will_run 'jan 1 2010 10:30:00'
          assert_wont_run 'jan 1 2010 09:30:00'

          model.update(:at => '09:30')
          tick_at @now, :and_every_second_for => @sync_frequency + 1.second

          assert_will_run 'jan 1 2010 09:30:00'
          assert_wont_run 'jan 1 2010 10:30:00'
        end

        def test_daily_event_from_database_with_at_should_only_run_once
          DatabaseEventModelClass.create(:frequency => 1.day, :at => next_minute(@now).strftime('%H:%M'))
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          # tick from now, though specified :at time
          tick_at(@now, :and_every_second_for => (2 * @sync_frequency) + 1.second)

          assert_equal 1, @events_run.length
        end

        def test_event_from_databse_with_comma_separated_at_leads_to_multiple_event_ats
          DatabaseEventModelClass.create(:frequency => 1.day, :at => '16:20, 18:10')
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          tick_at @now, :and_every_second_for => 1.second

          assert_wont_run 'jan 1 2010 16:19:59'
          assert_will_run 'jan 1 2010 16:20:00'
          assert_wont_run 'jan 1 2010 16:20:01'

          assert_wont_run 'jan 1 2010 18:09:59'
          assert_will_run 'jan 1 2010 18:10:00'
          assert_wont_run 'jan 1 2010 18:10:01'
        end

        def test_syncing_multiple_database_models_works
          DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => @sync_frequency, :events_run => @events_run)

          DatabaseEventModelClass2.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass2, :every => @sync_frequency, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 1.second)

          assert_equal ["DatabaseEventModelClass:1", "DatabaseEventModelClass2:1"], @events_run
        end
      end

      context "when database reload frequency is less than model frequency period" do
        setup do
          @events_run = []
        end

        def test_the_event_only_runs_once_within_the_model_frequency_period
          DatabaseEventModelClass.create(:frequency => 5.minutes)
          setup_sync(model: DatabaseEventModelClass, :every => 1.minute, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 5.minutes)

          assert_equal 1, @events_run.length
        end
      end

      context "with database event with :at as empty string" do
        setup do
          @events_run = []

          DatabaseEventModelClass.create(:frequency => 10)
          setup_sync(model: DatabaseEventModelClass, :every => 1.minute, :events_run => @events_run)
        end

        def test_it_does_not_raise_an_error
          begin
            tick_at(Time.now, :and_every_second_for => 10.seconds)
          rescue => e
            assert false, "Raised an error: #{e.message}"
          end
        end

        def test_the_event_runs
          begin
            tick_at(Time.now, :and_every_second_for => 10.seconds)
          rescue => e
          end
          assert_equal 1, @events_run.length
        end
      end

      context "with task that respond to `tz`" do
        setup do
          @events_run = []
          @utc_time_now = Time.now.utc
          
          DatabaseEventModelClass.create(:frequency => 1.days, :at => @utc_time_now.strftime('%H:%M'), :tz => 'America/Montreal')
          setup_sync(model: DatabaseEventModelClass, :every => 1.minute, :events_run => @events_run)
        end

        def test_it_does_not_raise_an_error
          begin
            tick_at(@utc_time_now, :and_every_second_for => 10.seconds)
          rescue => e
            assert false, "Raised an error: #{e.message}"
          end
        end

        def test_it_do_not_runs_the_task_as_utc
          begin
            tick_at(@utc_time_now, :and_every_second_for => 3.hours)
          rescue => e
          end
          assert_equal 0, @events_run.length
        end

        def test_it_does_runs_the_task_as_est
          begin
            tick_at(@utc_time_now, :and_every_second_for => 5.hours)
          rescue => e
          end
          assert_equal 1, @events_run.length
        end
      end
    end
  end
end
