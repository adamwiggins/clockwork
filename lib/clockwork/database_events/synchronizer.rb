require_relative '../database_events'

module Clockwork

  module DatabaseEvents

    class Synchronizer

      def self.setup(options={}, &block_to_perform_on_event_trigger)
        model_class = options.fetch(:model) { raise KeyError, ":model must be set to the model class" }
        every = options.fetch(:every) { raise KeyError, ":every must be set to the database sync frequency" }

        event_store = EventStore.new(block_to_perform_on_event_trigger)

        # create event that syncs clockwork events with events coming from database-backed model
        Clockwork.manager.every every, "sync_database_events_for_model_#{model_class}" do
          event_store.update(model_class.all)
        end
      end
    end

  end
end
