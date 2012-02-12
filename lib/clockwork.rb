require 'logger'

module Clockwork

  @@events = []

  def configure
    yield(@@configuration)
  end

  class At
    class FailedToParse < StandardError; end;
    NOT_SPECIFIED = nil
    WDAYS = %w[sunday monday tuesday wednesday thursday friday saturday].map do |w|
      [w, w.capitalize, w[0...3], w[0...3].capitalize]
    end

    def self.parse(at)
      return unless at
      case at
      when /^([[:alpha:]]+)\s(.*)$/
        ret = parse($2)
        wday = WDAYS.find_index {|x| x.include?($1) }
        raise FailedToParse, at if wday.nil?
        ret.wday = wday
        ret
      when /^(\d{1,2}):(\d\d)$/
        new($2.to_i, $1.to_i)
      when /^\*{1,2}:(\d\d)$/
        new($1.to_i)
      else
        raise FailedToParse, at
      end
    rescue ArgumentError
      raise FailedToParse, at
    end

    attr_writer :min, :hour, :wday

    def initialize(min, hour=NOT_SPECIFIED, wday=NOT_SPECIFIED)
      if min.nil? || min < 0 || min > 59 ||
          (hour != NOT_SPECIFIED && (hour < 0 || hour > 23)) ||
          (wday != NOT_SPECIFIED && (wday < 0 || wday > 6))
        raise ArgumentError
      end
      @min = min
      @hour = hour
      @wday = wday
    end

    def ready?(t)
      t.min == @min and
        (@hour == NOT_SPECIFIED or t.hour == @hour) and
        (@wday == NOT_SPECIFIED or t.wday == @wday)
    end
  end

  class Event
    attr_accessor :job, :last

    def initialize(period, job, block, options={})
      @period = period
      @job = job
      @at = At.parse(options[:at])
      @last = nil
      @block = block
    end

    def to_s
      @job
    end

    def time?(t)
      ellapsed_ready = (@last.nil? or (t - @last).to_i >= @period)
      ellapsed_ready and (@at.nil? or @at.ready?(t))
    end

    def run(t)
      @last = t
      @block.call(@job)
    rescue => e
      log_error(e)
    end

    def log_error(e)
      STDERR.puts exception_message(e)
      Clockwork.config.logger.error(e)
    end

    def exception_message(e)
      msg = [ "Exception #{e.class} -> #{e.message}" ]

      base = File.expand_path(Dir.pwd) + '/'
      e.backtrace.each do |t|
        msg << "   #{File.expand_path(t).gsub(/#{base}/, '')}"
      end

      msg.join("\n")
    end
  end

  class Configuration
    def initialize(defaults = {})
      @backend = defaults.clone
    end
    
    def method_missing(method, *params, &block)
      if method.to_s =~ /^(.+)=/
        #setter method called
        @backend[Regexp.last_match[1].to_sym] = params.first
      else
        #getter method called
        @backend[method.to_sym]
      end
    end
  end

  @@configuration = Configuration.new(
    { :sleep_timeout => 1, :logger => Logger.new(STDOUT) }
  )
   
  def config
    @@configuration
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
      sleep(config.sleep_timeout)
    end
  end

  def log(msg)
    config.logger.info(msg)
  end

  def tick(t=Time.now)
    to_run = @@events.select do |event|
      event.time?(t)
    end

    to_run.each do |event|
      log "Triggering '#{event}' at #{Time.now}"
      event.run(t)
    end

    to_run
  end

  def clear!
    @@events = []
    @@handler = nil
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
