require File.expand_path('../../lib/clockwork', __FILE__)
require "minitest/autorun"
require 'mocha/setup'
require 'time'
require 'active_support/time'

describe Clockwork::Manager do
  before do
    @manager = Clockwork::Manager.new
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

  it "once a minute" do
    @manager.every(1.minute, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+30)
    assert_will_run(t+60)
  end

  it "every three minutes" do
    @manager.every(3.minutes, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+2*60)
    assert_will_run(t+3*60)
  end

  it "once an hour" do
    @manager.every(1.hour, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+30*60)
    assert_will_run(t+60*60)
  end

  it "once a week" do
    @manager.every(1.week, 'myjob')

    assert_will_run(t=Time.now)
    assert_wont_run(t+60*60*24*6)
    assert_will_run(t+60*60*24*7)
  end

  it "won't drift later and later" do
    @manager.every(1.hour, 'myjob')

    assert_will_run(Time.parse("10:00:00.5"))
    assert_wont_run(Time.parse("10:59:59.999"))
    assert_will_run(Time.parse("11:00:00.0"))
  end

  it "aborts when no handler defined" do
    manager = Clockwork::Manager.new
    assert_raises(Clockwork::Manager::NoHandlerDefined) do
      manager.every(1.minute, 'myjob')
    end
  end

  it "aborts when fails to parse" do
    assert_raises(Clockwork::At::FailedToParse) do
      @manager.every(1.day, "myjob", :at => "a:bc")
    end
  end

  it "general handler" do
    $set_me = 0
    @manager.handler { $set_me = 1 }
    @manager.every(1.minute, 'myjob')
    @manager.tick(Time.now)
    assert_equal 1, $set_me
  end

  it "event-specific handler" do
    $set_me = 0
    @manager.every(1.minute, 'myjob') { $set_me = 2 }
    @manager.tick(Time.now)

    assert_equal 2, $set_me
  end

  it "should pass time to the general handler" do
    received = nil
    now = Time.now
    @manager.handler { |job, time| received = time }
    @manager.every(1.minute, 'myjob')
    @manager.tick(now)
    assert_equal now, received
  end

  it "should pass time to the event-specific handler" do
    received = nil
    now = Time.now
    @manager.every(1.minute, 'myjob') { |job, time| received = time }
    @manager.tick(now)
    assert_equal now, received
  end

  it "exceptions are trapped and logged" do
    @manager.handler { raise 'boom' }
    @manager.every(1.minute, 'myjob')

    mocked_logger = MiniTest::Mock.new
    mocked_logger.expect :error, true, [RuntimeError]
    @manager.configure { |c| c[:logger] = mocked_logger }
    @manager.tick(Time.now)
    mocked_logger.verify
  end

  it "exceptions still set the last timestamp to avoid spastic error loops" do
    @manager.handler { raise 'boom' }
    event = @manager.every(1.minute, 'myjob')
    @manager.stubs(:log_error)
    @manager.tick(t = Time.now)
    assert_equal t, event.last
  end

  it "should be configurable" do
    @manager.configure do |config|
      config[:sleep_timeout] = 200
      config[:logger] = "A Logger"
      config[:max_threads] = 10
      config[:thread] = true
    end

    assert_equal 200, @manager.config[:sleep_timeout]
    assert_equal "A Logger", @manager.config[:logger]
    assert_equal 10, @manager.config[:max_threads]
    assert_equal true, @manager.config[:thread]
  end

  it "configuration should have reasonable defaults" do
    assert_equal 1, @manager.config[:sleep_timeout]
    assert @manager.config[:logger].is_a?(Logger)
    assert_equal 10, @manager.config[:max_threads]
    assert_equal false, @manager.config[:thread]
  end

  it "should accept unnamed job" do
    event = @manager.every(1.minute)
    assert_equal 'unnamed', event.job
  end

  it "should accept options without job name" do
    event = @manager.every(1.minute, {})
    assert_equal 'unnamed', event.job
  end

  describe ':at option' do
    it "once a day at 16:20" do
      @manager.every(1.day, 'myjob', :at => '16:20')

      assert_wont_run 'jan 1 2010 16:19:59'
      assert_will_run 'jan 1 2010 16:20:00'
      assert_wont_run 'jan 1 2010 16:20:01'
      assert_wont_run 'jan 2 2010 16:19:59'
      assert_will_run 'jan 2 2010 16:20:00'
    end

    it "twice a day at 16:20 and 18:10" do
      @manager.every(1.day, 'myjob', :at => ['16:20', '18:10'])

      assert_wont_run 'jan 1 2010 16:19:59'
      assert_will_run 'jan 1 2010 16:20:00'
      assert_wont_run 'jan 1 2010 16:20:01'

      assert_wont_run 'jan 1 2010 18:09:59'
      assert_will_run 'jan 1 2010 18:10:00'
      assert_wont_run 'jan 1 2010 18:10:01'
    end
  end

  describe ':tz option' do
    it "time zone is not set by default" do
      assert @manager.config[:tz].nil?
    end

    it "should be able to specify a different timezone than local" do
      @manager.every(1.day, 'myjob', :at => '10:00', :tz => 'UTC')

      assert_wont_run 'jan 1 2010 10:00:00 EST'
      assert_will_run 'jan 1 2010 10:00:00 UTC'
    end

    it "should be able to specify a different timezone than local for multiple times" do
      @manager.every(1.day, 'myjob', :at => ['10:00', '8:00'], :tz => 'UTC')

      assert_wont_run 'jan 1 2010 08:00:00 EST'
      assert_will_run 'jan 1 2010 08:00:00 UTC'
      assert_wont_run 'jan 1 2010 10:00:00 EST'
      assert_will_run 'jan 1 2010 10:00:00 UTC'
    end

    it "should be able to configure a default timezone to use for all events" do
      @manager.configure { |config| config[:tz] = 'UTC' }
      @manager.every(1.day, 'myjob', :at => '10:00')

      assert_wont_run 'jan 1 2010 10:00:00 EST'
      assert_will_run 'jan 1 2010 10:00:00 UTC'
    end

    it "should be able to override a default timezone in an event" do
      @manager.configure { |config| config[:tz] = 'UTC' }
      @manager.every(1.day, 'myjob', :at => '10:00', :tz => 'EST')

      assert_will_run 'jan 1 2010 10:00:00 EST'
      assert_wont_run 'jan 1 2010 10:00:00 UTC'
    end
  end

  describe ':if option' do
    it ":if true then always run" do
      @manager.every(1.second, 'myjob', :if => lambda { |_| true })

      assert_will_run 'jan 1 2010 16:20:00'
    end

    it ":if false then never run" do
      @manager.every(1.second, 'myjob', :if => lambda { |_| false })

      assert_wont_run 'jan 1 2010 16:20:00'
    end

    it ":if the first day of month" do
      @manager.every(1.second, 'myjob', :if => lambda { |t| t.day == 1 })

      assert_will_run 'jan 1 2010 16:20:00'
      assert_wont_run 'jan 2 2010 16:20:00'
      assert_will_run 'feb 1 2010 16:20:00'
    end

    it ":if it is compared to a time with zone" do
      tz = 'America/Chicago'
      time = Time.utc(2012,5,25,10,00)
      @manager.every(1.second, 'myjob', tz: tz, :if => lambda  { |t|
            ((time - 1.hour)..(time + 1.hour)).cover? t
            })
      assert_will_run time
    end

    it ":if is not callable then raise ArgumentError" do
      assert_raises(ArgumentError) do
        @manager.every(1.second, 'myjob', :if => true)
      end
    end
  end

  describe "max_threads" do
    it "should warn when an event tries to generate threads more than max_threads" do
      logger = Logger.new(STDOUT)
      @manager.configure do |config|
        config[:max_threads] = 1
        config[:logger] = logger
      end

      @manager.every(1.minute, 'myjob1', :thread => true) { sleep 2 }
      @manager.every(1.minute, 'myjob2', :thread => true) { sleep 2 }
      logger.expects(:error).with("Threads exhausted; skipping myjob2")

      @manager.tick(Time.now)
    end

    it "should not warn when thread is managed by others" do
      begin
        t = Thread.new { sleep 5 }
        logger = Logger.new(StringIO.new)
        @manager.configure do |config|
          config[:max_threads] = 1
          config[:logger] = logger
        end

        @manager.every(1.minute, 'myjob', :thread => true)
        logger.expects(:error).never

        @manager.tick(Time.now)
      ensure
        t.kill
      end
    end
  end

  describe "callbacks" do
    it "should not accept unknown callback name" do
      assert_raises(RuntimeError, "Unsupported callback unknown_callback") do
        @manager.on(:unknown_callback) do
          true
        end
      end
    end

    it "should run before_tick callback once on tick" do
      counter = 0
      @manager.on(:before_tick) do
        counter += 1
      end
      @manager.tick
      assert_equal 1, counter
    end

    it "should not run events if before_tick returns false" do
      @manager.on(:before_tick) do
        false
      end
      @manager.every(1.second, 'myjob') { raise "should not run" }
      @manager.tick
    end

    it "should run before_run twice if two events are registered" do
      counter = 0
      @manager.on(:before_run) do
        counter += 1
      end
      @manager.every(1.second, 'myjob')
      @manager.every(1.second, 'myjob2')
      @manager.tick
      assert_equal 2, counter
    end

    it "should run even jobs only" do
      counter = 0
      ran = false
      @manager.on(:before_run) do
        counter += 1
        counter % 2 == 0
      end
      @manager.every(1.second, 'myjob') { raise "should not ran" }
      @manager.every(1.second, 'myjob2') { ran = true }
      @manager.tick
      assert ran
    end

    it "should run after_run callback for each event" do
      counter = 0
      @manager.on(:after_run) do
        counter += 1
      end
      @manager.every(1.second, 'myjob')
      @manager.every(1.second, 'myjob2')
      @manager.tick
      assert_equal 2, counter
    end

    it "should run after_tick callback once" do
      counter = 0
      @manager.on(:after_tick) do
        counter += 1
      end
      @manager.tick
      assert_equal 1, counter
    end
  end

  describe 'error_handler' do
    before do
      @errors = []
      @manager.error_handler do |e|
        @errors << e
      end

      # block error log
      @string_io = StringIO.new
      @manager.configure do |config|
        config[:logger] = Logger.new(@string_io)
      end
      @manager.every(1.second, 'myjob') { raise 'it error' }
    end

    it 'registered error_handler handles error from event' do
      @manager.tick
      assert_equal ['it error'], @errors.map(&:message)
    end

    it 'error is notified to logger and handler' do
      @manager.tick
      assert @string_io.string.include?('it error')
    end

    it 'error in handler will NOT be suppressed' do
      @manager.error_handler do |e|
        raise e.message + ' re-raised'
      end
      assert_raises(RuntimeError, 'it error re-raised') do
        @manager.tick
      end
    end
  end
end
