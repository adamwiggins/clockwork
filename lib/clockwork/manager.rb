module Clockwork
  class Manager
    class NoHandlerDefined < RuntimeError; end

    attr_reader :config

    def initialize
      @events = []
      @config = default_configuration
      @handler = nil
    end

    def thread_available?
      Thread.list.count < config[:max_threads]
    end

    def configure
      yield(config)
    end

    def default_configuration
      { :sleep_timeout => 1, :logger => Logger.new(STDOUT), :thread => false, :max_threads => 10 }
    end

    def handler(&block)
      @handler = block
    end

    def get_handler
      raise NoHandlerDefined unless (defined?(@handler) and @handler)
      @handler
    end

    def every(period, job, options={}, &block)
      if options[:at].respond_to?(:each)
        every_with_multiple_times(period, job, options, &block)
      else
        register(period, job, block, options)
      end
    end

    def run
      log "Starting clock for #{@events.size} events: [ " + @events.map { |e| e.to_s }.join(' ') + " ]"
      loop do
        tick
        sleep(config[:sleep_timeout])
      end
    end

    def tick(t=Time.now)
      to_run = @events.select do |event|
        event.time?(t)
      end

      to_run.each do |event|
        log "Triggering '#{event}'"
        event.run(t)
      end

      to_run
    end

    private
    def log(msg)
      config[:logger].info(msg)
    end

    def register(period, job, block, options)
      event = Event.new(self, period, job, block || get_handler, parse_event_option(options))
      @events << event
      event
    end

    def parse_event_option(options)
      if options[:if]
        if !options[:if].respond_to?(:call)
          raise ArgumentError.new(':if expects a callable object, but #{options[:if]} does not respond to call')
        end
      end

      options[:thread] = !!(options.has_key?(:thread) ? options[:thread] : config[:thread])
      options[:tz] ||= config[:tz]

      options
    end
    
    def every_with_multiple_times(period, job, options={}, &block)
      each_options = options.clone
      options[:at].each do |at|
        each_options[:at] = at
        register(period, job, block, each_options)
      end
    end
  end
end
