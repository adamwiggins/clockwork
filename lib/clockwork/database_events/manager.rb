module Clockwork

  module DatabaseEvents

    class Manager < Clockwork::Manager

      def unregister(event)
        @events.delete(event)
      end

      def register(period, job, block, options)
        @events << if options[:from_database]
          synchronizer = options.fetch(:synchronizer)
          model_attributes = options.fetch(:model_attributes)

          Clockwork::DatabaseEvents::Event.
            new(self, period, job, (block || handler), synchronizer, model_attributes, options)
        else
          Clockwork::Event.new(self, period, job, block || handler, options)
        end
      end
    end
  end
end
