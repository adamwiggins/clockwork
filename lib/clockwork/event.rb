module Clockwork
  class Event
    attr_accessor :job, :last

    def initialize(manager, period, job, block, options={})
      @manager = manager
      @period = period
      @job = job
      @at = At.parse(options[:at])
      @last = nil
      @block = block
      @if = options[:if]
      @thread = options[:thread]
      @timezone = options[:tz]
    end

    def to_s
      @job
    end

    def convert_timezone(t)
      @timezone ? t.in_time_zone(@timezone) : t
    end

    def time?(t)
      t = convert_timezone(t)
      elapsed_ready = (@last.nil? or (t - @last).to_i >= @period)
      elapsed_ready and (@at.nil? or @at.ready?(t)) and (@if.nil? or @if.call(t))
    end

    def thread?
      @thread
    end

    def run(t)
      t = convert_timezone(t)
      @last = t

      if thread?
        if @manager.thread_available?
          Thread.new { execute }
        else
          log_error "Threads exhausted; skipping #{self}"
        end
      else
        execute
      end
    end

    def execute
      @block.call(@job, @last)
    rescue => e
      log_error e
      handle_error e
    end

    def log_error(e)
      @manager.config[:logger].error(e)
    end

    def handle_error(e)
      if handler = @manager.get_error_handler
        handler.call(e)
      end
    end
  end
end
