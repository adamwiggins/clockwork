require_relative './event_collection'

# How EventStore and Clockwork manager events are kept in sync...
#
# The normal Clockwork::Manager is responsible for keeping track of
# Clockwork events, and ensuring they are scheduled at the correct time.
# It has an @events array for this purpose.

# For keeping track of Database-backed events though, we need to keep
# track of more information about the events, e.g. the block which should
# be triggered when they are run, which model the event comes from, the
# model ID it relates to etc. Therefore, we devised a separate mechanism
# for keeping track of these database-backed events: the per-model EventStore.

# Having two classes responsible for keeping track of events though leads to
# a slight quirk, in that these two have to be kept in sync. The way this is
# done is by letting the EventStore largely defer to the Clockwork Manager.

# 1. When the EventStore wishes to recreate events:
#   - it asks the Clockwork.manager to do this for it
#   - by calling Clockwork.manager.every

# 2. When the DatabaseEvents::Manager creates events (via its #register)
#   - it creates a new DatabaseEvents::Event
#   - DatabaseEvents::Event#initialize registers it with the EventStore
module Clockwork

  module DatabaseEvents

    class EventStore

      def initialize(block_to_perform_on_event_trigger)
        @related_events = {}
        @block_to_perform_on_event_trigger = block_to_perform_on_event_trigger
      end

      # DatabaseEvents::Manager#register creates a new DatabaseEvents::Event, whose
      # #initialize method registers the new database event with the EventStore by
      # calling this method.
      def register(event, model)
        related_events_for(model.id).add(event)
      end

      def update(current_model_objects)
        unregister_all_except(current_model_objects)
        update_registered_models(current_model_objects)
        register_new_models(current_model_objects)
      end

      def unregister_all_except(model_objects)
        ids = model_objects.collect(&:id)
        (@related_events.keys - ids).each{|id| unregister(id) }
      end

      def update_registered_models(model_objects)
        registered_models(model_objects).each do |model|
          if has_changed?(model)
            unregister(model.id)
            register_with_manager(model)
          end
        end
      end

      def register_new_models(model_objects)
        unregistered_models(model_objects).each do |new_model_object|
          register_with_manager(new_model_object)
        end
      end

      private

      attr_reader :related_events

      def registered?(model)
        related_events_for(model.id) != nil
      end

      def has_changed?(model)
        related_events_for(model.id).has_changed?(model)
      end

      def related_events_for(id)
        related_events[id] ||= EventCollection.new
      end

      def registered_models(model_objects)
        model_objects.select{|m| registered?(m) }
      end

      def unregistered_models(model_objects)
        model_objects.select{|m| !registered?(m) }
      end

      def unregister(id)
        related_events_for(id).unregister
        related_events.delete(id)
      end

      # When re-creating events, the Clockwork.manager must be used to
      # create them, as it is ultimately responsible for ensuring that
      # the events actually get run when they should. We call its #every
      # method, which will result in DatabaseEvent::Manager#register being
      # called, which creates a new DatabaseEvent::Event, which will be
      # registered with the EventStore on #initialize.
      def register_with_manager(model)
        Clockwork.manager.
          every(model.frequency, model, options(model),
                &@block_to_perform_on_event_trigger)
      end

      def options(model)
        options = {
          :from_database => true,
          :synchronizer => self,
        }

        options[:at] = at_strings_for(model) if model.respond_to?(:at)
        options[:if] = ->(time){ model.if?(time) } if model.respond_to?(:if?)
        options[:tz] = model.tz if model.respond_to?(:tz)

        # store the state of the model at time of registering so we can
        # easily compare and determine if state has changed later
        options[:model_attributes] = model.attributes

        options
      end

      def at_strings_for(model)
        return nil if model.at.to_s.empty?

        model.at.split(',').map(&:strip)
      end
    end

  end
end
