require_relative '../database_events'

module Clockwork

  module DatabaseEvents

    class SyncPerformer

      PERFORMERS = []

      def self.setup(options={}, &block)
        model_class = options.fetch(:model) { raise KeyError, ":model must be set to the model class" }
        every = options.fetch(:every) { raise KeyError, ":every must be set to the database sync frequency" }

        sync_performer = self.new(model_class, &block)

        # create event that syncs clockwork events with events coming from database-backed model
        Clockwork.manager.every every, "sync_database_events_for_model_#{model_class}" do
          sync_performer.sync
        end
      end

      def initialize(model_class, &proc)
        @model_class = model_class
        @block = proc
        @database_event_registry = Registry.new

        PERFORMERS << self
      end

      # delegates to Registry
      def register(event, model)
        @database_event_registry.register(event, model)
      end

      # Ensure clockwork events reflect events from database-backed model
      # Adds any new events, modifies updated ones, and delets removed ones
      def sync
        model_ids_that_exist = []

        @model_class.all.each do |model|
          model_ids_that_exist << model.id
          if are_different?(@database_event_registry.event_for(model), model)
            create_or_recreate_event(model)
          end
        end
        @database_event_registry.unregister_all_except(model_ids_that_exist)
      end

      private
      def are_different?(event, model)
        return true if event.nil?
        event.name_or_frequency_has_changed?(model) || ats_have_changed?(model)
      end

      def ats_have_changed?(model)
        model_ats = ats_array_for_event(model)
        event_ats = ats_array_from_model(model)

        model_ats != event_ats
      end

      def ats_array_for_event(model)
        @database_event_registry.events_for(model).collect{|event| event.at }.compact
      end

      def ats_array_from_model(model)
        (at_strings_for(model) || []).collect{|at| At.parse(at) }
      end

      def at_strings_for(model)
        model.at.to_s.empty? ? nil : model.at.split(',').map(&:strip)
      end

      def create_or_recreate_event(model)
        if @database_event_registry.event_for(model)
          @database_event_registry.unregister(model)
        end

        options = {
          :from_database => true,
          :sync_performer => self,
          :at => at_strings_for(model)
        }

        options[:tz] = model.tz if model.respond_to?(:tz)

        # we pass actual model instance as the job, rather than just name
        Clockwork.manager.every model.frequency, model, options, &@block
      end
    end

  end
end