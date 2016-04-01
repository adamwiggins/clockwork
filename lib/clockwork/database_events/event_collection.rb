module Clockwork
  module DatabaseEvents
    class EventCollection

      def initialize(manager=Clockwork.manager)
        @events = []
        @manager = manager
      end

      def add(event)
        @events << event
      end

      def has_changed?(model)
        return true if event.nil?

        (has_name? && name != model.name) ||
          frequency != model.frequency ||
            ats != model_ats(model)
      end

      def unregister
        events.each{|e| manager.unregister(e) }
      end

      private

      attr_reader :events, :manager

      def event
        events.first
      end

      def has_name?
        event.job_has_name?
      end

      def name
        event.name
      end

      def frequency
        event.frequency
      end

      def ats
        events.collect(&:at).compact
      end

      def model_ats(model)
        at_strings_for(model).collect{|at| At.parse(at) }
      end

      def at_strings_for(model)
        model.at.to_s.split(',').map(&:strip)
      end
    end
  end
end
