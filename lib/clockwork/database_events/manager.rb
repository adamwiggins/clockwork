module Clockwork

  module DatabaseEvents

    class ManagerWithDatabaseEvents < Manager

      def unregister(event)
        @events.remove(event) # TODO: check syntax!
      end

      private

      def register(period, job, block, options)
        @events << if options[:from_database]
          DatabaseEvent.new(self, period, job, block || handler, options.fetch(:sync_performer), options)
        else
          Event.new(self, period, job, block || handler, options)
        end
      end

    end
  end
end
