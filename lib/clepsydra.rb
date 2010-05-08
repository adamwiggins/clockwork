module Clepsydra
	class Job
		def initialize(span, &block)
			@secs = parse_span(span)
			@last = nil
			@block = block
		end

		def time?
			@last.nil? or (Time.now - @last).to_i >= @secs
		end

		def run
			@block.call
			@last = Time.now
		end

		class FailedToParse < RuntimeError; end

		def parse_span(span)
			m = span.match(/^(\d+)([smh])$/)
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
	end

	extend self

	def every(span, &block)
		@@clocks ||= []
		@@clocks << Job.new(span, &block)
	end

	def run
		loop do
			@@clocks.each do |clock|
				clock.run if clock.time?
			end
			sleep 1
		end
	end
end
