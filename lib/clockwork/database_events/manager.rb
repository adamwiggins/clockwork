module Clockwork

  module DatabaseEvents

    class Manager < Clockwork::Manager

      def unregister(event)
        @events.delete(event)
      end

      def register(period, job, block, options)
        @events << if options[:from_database]
          Clockwork::DatabaseEvents::Event.new(self, period, job, (block || handler), options.fetch(:sync_performer), options)
        else
          Clockwork::Event.new(self, period, job, block || handler, options)
        end
      end
    end
  end
end
