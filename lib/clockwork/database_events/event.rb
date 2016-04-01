module Clockwork

  module DatabaseEvents

    class Event < Clockwork::Event

      attr_accessor :event_store, :at

      def initialize(manager, period, job, block, event_store, options={})
        super(manager, period, job, block, options)
        @event_store = event_store
        @event_store.register(self, job)
      end

      def name
        (job_has_name? && job.name) ? job.name : "#{job.class}:#{job.id}"
      end

      def job_has_name?
        job.respond_to?(:name)
      end

      def to_s
        name
      end

      def frequency
        @period
      end
    end

  end
end
