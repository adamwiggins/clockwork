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

    alias_method :to_s, :job

    def convert_timezone(t)
      @timezone ? t.in_time_zone(@timezone) : t
    end

    def run_now?(t)
      t = convert_timezone(t)
      elapsed_ready(t) and (@at.nil? or @at.ready?(t)) and (@if.nil? or @if.call(t))
    end

    def thread?
      @thread
    end

    def run(t)
      @manager.log "Triggering '#{self}'"
      @last = convert_timezone(t)
      if thread?
        if @manager.thread_available?
          Thread.new { execute }
        else
          @manager.log_error "Threads exhausted; skipping #{self}"
        end
      else
        execute
      end
    end

    def execute
      @block.call(@job, @last)
    rescue => e
      @manager.log_error e
      @manager.handle_error e
    end

    private
    def elapsed_ready(t)
      @last.nil? || (t - @last).to_i >= @period
    end
  end
end
