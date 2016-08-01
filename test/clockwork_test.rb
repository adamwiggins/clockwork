require File.expand_path('../../lib/clockwork', __FILE__)
require 'minitest/autorun'
require 'mocha/setup'

describe Clockwork do
  before do
    @log_output = StringIO.new
    Clockwork.configure do |config|
      config[:sleep_timeout] = 0
      config[:logger] = Logger.new(@log_output)
    end
  end

  after do
    Clockwork.clear!
  end

  it 'should run events with configured logger' do
    run = false
    Clockwork.handler do |job|
      run = job == 'myjob'
    end
    Clockwork.every(1.minute, 'myjob')
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run

    assert run
    assert @log_output.string.include?('Triggering')
  end

  it 'should log event correctly' do
    run = false
    Clockwork.handler do |job|
      run = job == 'an event'
    end
    Clockwork.every(1.minute, 'an event')
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert run
    assert @log_output.string.include?("Triggering 'an event'")
  end

  it 'should pass event without modification to handler' do
    event_object = Object.new
    run = false
    Clockwork.handler do |job|
      run = job == event_object
    end
    Clockwork.every(1.minute, event_object)
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert run
  end

  it 'should not run anything after reset' do
    Clockwork.every(1.minute, 'myjob') {  }
    Clockwork.clear!
    Clockwork.configure do |config|
      config[:sleep_timeout] = 0
      config[:logger] = Logger.new(@log_output)
    end
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert @log_output.string.include?('0 events')
  end

  it 'should pass all arguments to every' do
    Clockwork.every(1.second, 'myjob', if: lambda { |_| false }) {  }
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert @log_output.string.include?('1 events')
    assert !@log_output.string.include?('Triggering')
  end

  it 'support module re-open style' do
    $called = false
    module ::Clockwork
      every(1.second, 'myjob') { $called = true }
    end
    Clockwork.manager.expects(:loop).yields.then.returns
    Clockwork.run
    assert $called
  end
end
