require 'logger'
require 'active_support/time'

require 'clockwork/at'
require 'clockwork/event'
require 'clockwork/manager'

module Clockwork

  @@events = []

  def thread_available?
    Thread.list.count < config[:max_threads]
  end

  def configure
    yield(config)
  end

  def config
    @@configuration
  end

  extend self

  def default_configuration
    { :sleep_timeout => 1, :logger => Logger.new(STDOUT), :thread => false, :max_threads => 10 }
  end

  @@configuration = default_configuration

  def handler(&block)
    @@handler = block
  end

  class NoHandlerDefined < RuntimeError; end

  def get_handler
    raise NoHandlerDefined unless (defined?(@@handler) and @@handler)
    @@handler
  end

  def every(period, job, options={}, &block)
    if options[:at].respond_to?(:each)
      each_options = options.clone
      options[:at].each do |at|
        each_options[:at] = at
        register(period, job, block, each_options)
      end
    else
      register(period, job, block, options)
    end
  end

  def run
    log "Starting clock for #{@@events.size} events: [ " + @@events.map { |e| e.to_s }.join(' ') + " ]"
    loop do
      tick
      sleep(config[:sleep_timeout])
    end
  end

  def log(msg)
    config[:logger].info(msg)
  end

  def tick(t=Time.now)
    to_run = @@events.select do |event|
      event.time?(t)
    end

    to_run.each do |event|
      log "Triggering '#{event}'"
      event.run(t)
    end

    to_run
  end

  def clear!
    @@events = []
    @@handler = nil
    @@configuration = Clockwork.default_configuration
  end

  private
  def register(period, job, block, options)
    event = Event.new(period, job, block || get_handler, options)
    @@events << event
    event
  end

end

unless 1.respond_to?(:seconds)
  class Numeric
    def seconds; self; end
    alias :second :seconds

    def minutes; self * 60; end
    alias :minute :minutes

    def hours; self * 3600; end
    alias :hour :hours

    def days; self * 86400; end
    alias :day :days

    def weeks; self * 604800; end
    alias :week :weeks
  end
end
