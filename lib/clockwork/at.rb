module Clockwork
  class At
    class FailedToParse < StandardError; end

    NOT_SPECIFIED = nil
    WDAYS = %w[sunday monday tuesday wednesday thursday friday saturday].map do |w|
      [w, w.capitalize, w[0...3], w[0...3].capitalize]
    end

    def self.parse(at)
      return unless at
      case at
      when /^([[:alpha:]]+)\s(.*)$/
        ret = parse($2)
        wday = WDAYS.find_index { |x| x.include?($1) }
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
end
