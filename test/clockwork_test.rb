require File.expand_path('../../lib/clockwork', __FILE__)
require 'contest'
require 'timeout'

class ClockworkTest < Test::Unit::TestCase
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

  def run_in_thread
    Thread.new do
      Clockwork.run
    end
  end

  test 'should run events with configured logger' do
    run = false
    string_io = set_string_io_logger
    Clockwork.handler do |job|
      run = job == 'myjob'
    end
    Clockwork.every(1.minute, 'myjob')

    runner = run_in_thread

    timeout(5) do
      sleep 1 until run
    end
    runner.kill
    assert run
    assert string_io.string.include?('Triggering')
  end

  test 'should not run anything after reset' do
    Clockwork.every(1.minute, 'myjob') {  }
    Clockwork.clear!

    string_io = set_string_io_logger
    runner = run_in_thread
    sleep 1
    runner.kill
    assert string_io.string.include?('0 events')
  end

  test 'should pass all arguments to every' do
    Clockwork.every(1.second, 'myjob', if: lambda { false }) {  }
    string_io = set_string_io_logger
    runner = run_in_thread
    sleep 1
    runner.kill
    assert string_io.string.include?('1 events')
    assert !string_io.string.include?('Triggering')
  end

  test 'support module re-open style' do
    $called = false
    module ::Clockwork
      every(1.second, 'myjob') { $called = true }
    end
    set_string_io_logger
    runner = run_in_thread
    sleep 1
    runner.kill

    assert $called
  end
end
