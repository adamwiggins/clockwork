require File.expand_path('../../lib/clockwork', __FILE__)
require 'contest'
require 'mocha/setup'

class ClockworkTest < Test::Unit::TestCase
  setup do
    Clockwork.configure do |config|
      config[:sleep_timeout] = 0
    end
  end

  teardown do
    Clockwork.clear!
  end

  def set_string_io_logger
    string_io = StringIO.new
    Clockwork.configure do |config|
      config[:logger] = Logger.new(string_io)
    end
    string_io
  end

  test 'should run events with configured logger' do
    run = false
    string_io = set_string_io_logger
    Clockwork.handler do |job|
      run = job == 'myjob'
    end
    Clockwork.every(1.minute, 'myjob')
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert run
    assert string_io.string.include?('Triggering')
  end

  test 'should log event correctly' do
    run = false
    string_io = set_string_io_logger
    Clockwork.handler do |job|
      run = job == 'an event'
    end
    Clockwork.every(1.minute, 'an event')
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert run
    assert string_io.string.include?("Triggering 'an event'")
  end

  test 'should pass event without modification to handler' do
    event_object = Object.new
    run = false
    string_io = set_string_io_logger
    Clockwork.handler do |job|
      run = job == event_object
    end
    Clockwork.every(1.minute, event_object)
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert run
  end

  test 'should not run anything after reset' do
    Clockwork.every(1.minute, 'myjob') {  }
    Clockwork.clear!
    Clockwork.configure do |config|
      config[:sleep_timeout] = 0
    end
    string_io = set_string_io_logger
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert string_io.string.include?('0 events')
  end

  test 'should pass all arguments to every' do
    Clockwork.every(1.second, 'myjob', if: lambda { |_| false }) {  }
    string_io = set_string_io_logger
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert string_io.string.include?('1 events')
    assert !string_io.string.include?('Triggering')
  end

  test 'support module re-open style' do
    $called = false
    module ::Clockwork
      every(1.second, 'myjob') { $called = true }
    end
    set_string_io_logger
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert $called
  end
end
