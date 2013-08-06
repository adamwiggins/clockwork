module Clockwork
  class Event
    attr_accessor :job, :last

    def initialize(period, job, block, options={})
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
        if Clockwork.thread_available?
          Thread.new { execute }
        else
          log_error "Threads exhausted; skipping #{self}"
        end
      else
        execute
      end
    end

    def execute
      @block.call(@job)
    rescue => e
      log_error e
    end

    def log_error(e)
      Clockwork.config[:logger].error(e)
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
end
