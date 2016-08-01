require "minitest/autorun"
require 'mocha/setup'
require 'time'
require 'active_support/time'

require_relative '../../lib/clockwork'
require_relative '../../lib/clockwork/database_events'
require_relative 'test_helpers'

describe Clockwork::DatabaseEvents::Synchronizer do
  before do
    @now = Time.now

    Clockwork.manager = @manager = Clockwork::DatabaseEvents::Manager.new
    class << @manager
      def log(msg); end # silence log output
    end
  end

  after do
    Clockwork.clear!
    DatabaseEventModel.delete_all
    DatabaseEventModel2.delete_all
    DatabaseEventModelWithIf.delete_all
  end

  describe "setup" do
    before do
      @subject = Clockwork::DatabaseEvents::Synchronizer
    end

    describe "arguments" do
      it 'raises argument error if model is not set' do
        error = assert_raises KeyError do
          @subject.setup(every: 1.minute) {}
        end
        assert_equal error.message, ":model must be set to the model class"
      end

      it 'raises argument error if every is not set' do
        error = assert_raises KeyError do
          @subject.setup(model: DatabaseEventModel) {}
        end
        assert_equal error.message, ":every must be set to the database sync frequency"
      end
    end

    describe "when database reload frequency is greater than model frequency period" do
      before do
        @events_run = []
        @sync_frequency = 1.minute
      end

      it 'fetches and registers event from database' do
        DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => 1.second)

        assert_equal ["DatabaseEventModel:1"], @events_run
      end

      it 'fetches and registers multiple events from database' do
        DatabaseEventModel.create(:frequency => 10)
        DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => 1.second)

        assert_equal ["DatabaseEventModel:1", "DatabaseEventModel:2"], @events_run
      end

      it 'does not run event again before frequency specified in database' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => model.frequency - 1.second)
        assert_equal 1, @events_run.length
      end

      it 'runs event repeatedly with frequency specified in database' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => (2 * model.frequency) + 1.second)

        assert_equal 3, @events_run.length
      end

      it 'runs reloaded events from database repeatedly' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => @sync_frequency - 1)
        model.update(:name => "DatabaseEventModel:1:Reloaded")
        tick_at(@now + @sync_frequency, :and_every_second_for => model.frequency * 2)

        assert_equal ["DatabaseEventModel:1:Reloaded", "DatabaseEventModel:1:Reloaded"], @events_run[-2..-1]
      end

      it 'updates modified event frequency with event reloading' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => @sync_frequency - 1.second)
        model.update(:frequency => 5)
        tick_at(@now + @sync_frequency, :and_every_second_for => 6.seconds)

        # model runs at: 1, 11, 21, 31, 41, 51 (6 runs)
        # database sync happens at: 60
        # modified model runs at: 61 (next tick after reload) and then 66 (2 runs)
        assert_equal 8, @events_run.length
      end

      it 'stoped running deleted events from database' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => (@sync_frequency - 1.second))
        before = @events_run.dup
        model.delete!
        tick_at(@now + @sync_frequency, :and_every_second_for => @sync_frequency)
        after = @events_run

        assert_equal before, after
      end

      it 'updates event name with new name' do
        model = DatabaseEventModel.create(:frequency => 10.seconds)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at @now, :and_every_second_for => @sync_frequency - 1.second
        @events_run.clear
        model.update(:name => "DatabaseEventModel:1_modified")
        tick_at @now + @sync_frequency, :and_every_second_for => (model.frequency * 2)

        assert_equal ["DatabaseEventModel:1_modified", "DatabaseEventModel:1_modified"], @events_run
      end

      it 'updates event frequency with new frequency' do
        model = DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at @now, :and_every_second_for => @sync_frequency - 1.second
        @events_run.clear
        model.update(:frequency => 30)
        tick_at @now + @sync_frequency, :and_every_second_for => @sync_frequency - 1.seconds

        assert_equal 2, @events_run.length
      end

      it 'updates event at with new at' do
        model = DatabaseEventModel.create(:frequency => 1.day, :at => '10:30')
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        assert_will_run 'jan 1 2010 10:30:00'
        assert_wont_run 'jan 1 2010 09:30:00'

        model.update(:at => '09:30')
        tick_at @now, :and_every_second_for => @sync_frequency + 1.second

        assert_will_run 'jan 1 2010 09:30:00'
        assert_wont_run 'jan 1 2010 10:30:00'
      end

      describe "when #name is defined" do
        it 'runs daily event with at from databse only once' do
          DatabaseEventModel.create(:frequency => 1.day, :at => next_minute(@now).strftime('%H:%M'))
          setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

          # tick from now, though specified :at time
          tick_at(@now, :and_every_second_for => (2 * @sync_frequency) + 1.second)

          assert_equal 1, @events_run.length
        end
      end

      describe "when #name is not defined" do
        it 'runs daily event with at from databse only once' do
          DatabaseEventModelWithoutName.create(:frequency => 1.day, :at => next_minute(next_minute(@now)).strftime('%H:%M'))
          setup_sync(model: DatabaseEventModelWithoutName, :every => @sync_frequency, :events_run => @events_run)

          # tick from now, though specified :at time
          tick_at(@now, :and_every_second_for => (2 * @sync_frequency) + 1.second)

          assert_equal 1, @events_run.length
        end
      end

      it 'creates multiple event ats with comma separated at string' do
        DatabaseEventModel.create(:frequency => 1.day, :at => '16:20, 18:10')
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        tick_at @now, :and_every_second_for => 1.second

        assert_wont_run 'jan 1 2010 16:19:59'
        assert_will_run 'jan 1 2010 16:20:00'
        assert_wont_run 'jan 1 2010 16:20:01'

        assert_wont_run 'jan 1 2010 18:09:59'
        assert_will_run 'jan 1 2010 18:10:00'
        assert_wont_run 'jan 1 2010 18:10:01'
      end

      it 'allows syncing multiple database models' do
        DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => @sync_frequency, :events_run => @events_run)

        DatabaseEventModel2.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel2, :every => @sync_frequency, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => 1.second)

        assert_equal ["DatabaseEventModel:1", "DatabaseEventModel2:1"], @events_run
      end
    end

    describe "when database reload frequency is less than model frequency period" do
      before do
        @events_run = []
      end

      it 'runs event only once within the model frequency period' do
        DatabaseEventModel.create(:frequency => 5.minutes)
        setup_sync(model: DatabaseEventModel, :every => 1.minute, :events_run => @events_run)

        tick_at(@now, :and_every_second_for => 5.minutes)

        assert_equal 1, @events_run.length
      end
    end

    describe "with database event :at set to empty string" do
      before do
        @events_run = []

        DatabaseEventModel.create(:frequency => 10)
        setup_sync(model: DatabaseEventModel, :every => 1.minute, :events_run => @events_run)
      end

      it 'does not raise an error' do
        begin
          tick_at(Time.now, :and_every_second_for => 10.seconds)
        rescue => e
          assert false, "Raised an error: #{e.message}"
        end
      end

      it 'runs the event' do
        begin
          tick_at(Time.now, :and_every_second_for => 10.seconds)
        rescue
        end
        assert_equal 1, @events_run.length
      end
    end

    describe "with model that responds to `if?`" do

      before do
        @events_run = []
      end

      describe "when model.if? is true" do
        it 'runs' do
          DatabaseEventModelWithIf.create(:if_state => true, :frequency => 10)
          setup_sync(model: DatabaseEventModelWithIf, :every => 1.minute, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 9.seconds)

          assert_equal 1, @events_run.length
        end
      end

      describe "when model.if? is false" do
        it 'does not run' do
          DatabaseEventModelWithIf.create(:if_state => false, :frequency => 10, :name => 'model with if?')
          setup_sync(model: DatabaseEventModelWithIf, :every => 1.minute, :events_run => @events_run)

          tick_at(@now, :and_every_second_for => 1.minute)

          # require 'byebug'
          # byebug if events_run.length > 0
          assert_equal 0, @events_run.length
        end
      end
    end

    describe "with task that responds to `tz`" do
      before do
        @events_run = []
        @utc_time_now = Time.now.utc

        DatabaseEventModel.create(:frequency => 1.days, :at => @utc_time_now.strftime('%H:%M'), :tz => 'America/Montreal')
        setup_sync(model: DatabaseEventModel, :every => 1.minute, :events_run => @events_run)
      end

      it 'does not raise an error' do
        begin
          tick_at(@utc_time_now, :and_every_second_for => 10.seconds)
        rescue => e
          assert false, "Raised an error: #{e.message}"
        end
      end

      it 'does not run the event based on UTC' do
        begin
          tick_at(@utc_time_now, :and_every_second_for => 3.hours)
        rescue
        end
        assert_equal 0, @events_run.length
      end

      it 'runs the event based on America/Montreal tz' do
        begin
          tick_at(@utc_time_now, :and_every_second_for => 5.hours)
        rescue
        end
        assert_equal 1, @events_run.length
      end
    end
  end
end
