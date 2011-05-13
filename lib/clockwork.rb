module Clockwork
  class FailedToParse < StandardError; end;

  class Event
    attr_accessor :job, :last

    def initialize(period, job, block, options={})
      @period = period
      @job = job
      @at = parse_at(options[:at])
      @last = nil
      @block = block
    end

    def to_s
      @job
    end

    def time?(t)
      ellapsed_ready = (@last.nil? or (t - @last).to_i >= @period)
      time_ready = (@at.nil? or (t.hour == @at[0] and t.min == @at[1]))
      ellapsed_ready and time_ready
    end

    def run(t)
      @last = t
      @block.call(@job)
    rescue => e
      log_error(e)
    end

    def log_error(e)
      STDERR.puts exception_message(e)
    end

    def exception_message(e)
      msg = [ "Exception #{e.class} -> #{e.message}" ]

      base = File.expand_path(Dir.pwd) + '/'
      e.backtrace.each do |t|
        msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
      end

      msg.join("\n")
    end

    def parse_at(at)
      return unless at
      m = at.match(/^(\d\d):(\d\d)$/)
      raise FailedToParse, at unless m
      hour, min = m[1].to_i, m[2].to_i
      raise FailedToParse, at if hour >= 24 or min >= 60
      [ hour, min ]
    end
  end

  extend self

  def handler(&block)
    @@handler = block
  end

  class NoHandlerDefined < RuntimeError; end

  def get_handler
    raise NoHandlerDefined unless (defined?(@@handler) and @@handler)
    @@handler
  end

  def every(period, job, options={}, &block)
    event = Event.new(period, job, block || get_handler, options)
    @@events ||= []
    @@events << event
    event
  end

  def run
    log "Starting clock for #{@@events.size} events: [ " + @@events.map { |e| e.to_s }.join(' ') + " ]"
    loop do
      tick
      sleep 1
    end
  end

  def log(msg)
    puts msg
  end

  def tick(t=Time.now)
    to_run = @@events.select do |event|
      event.time?(t)
    end

    to_run.each do |event|
      log "Triggering #{event}"
      event.run(t)
    end

    to_run
  end

  def clear!
    @@events = []
    @@handler = nil
  end
end

class Numeric
  def seconds; self; end
  alias :second :seconds

  def minutes; self * 60; end
  alias :minute :minutes

  def hours; self * 3600; end
  alias :hour :hours

  def days; self * 86400; end
  alias :day :days
end
