module Clockwork
	class Event
		def initialize(span, options={}, &block)
			@secs = parse_span(span)
			@at = parse_at(options[:at])
			@last = nil
			@block = block
		end

		def time?(t)
			ellapsed_ready = (@last.nil? or (t - @last).to_i >= @secs)
			time_ready = (@at.nil? or (t.hour == @at[0] and t.min == @at[1]))
			ellapsed_ready and time_ready
		end

		def run(t)
			@block.call
			@last = t
		end

		class FailedToParse < RuntimeError; end

		def parse_span(span)
			m = span.match(/^(\d+)([smhd])$/)
			raise FailedToParse, span unless m
			ordinal, magnitude = m[1].to_i, m[2]
			ordinal * magnitude_multiplier[magnitude]
		end

		def magnitude_multiplier
			{
				's' => 1,
				'm' => 60,
				'h' => 60*60,
				'd' => 24*60*60
			}
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

	def every(span, options={}, &block)
		@@events ||= []
		@@events << Event.new(span, options, &block)
	end

	def run
		loop do
			tick(Time.now)
			sleep 1
		end
	end

	def tick(t)
		@@events.each do |event|
			event.run(t) if event.time?(t)
		end
	end
end
