module Clockwork

  module DatabaseEvents

    class Registry

      def initialize
        @events = Hash.new []
      end

      def register(event, model)
        @events[model.id] = @events[model.id] + [event]
      end

      def unregister(model)
        unregister_by_id(model.id)
      end

      def unregister_by_id(id)
        @events[id].each{|e| Clockwork.manager.unregister(e) }
        @events.delete(id)
      end

      def unregister_all_except(ids)
        (@events.keys - ids).each{|id| unregister_by_id(id) }
      end

      # all events of same id will have same frequency/name, just different ats
      def event_for(model)
        events_for(model).first
      end

      def events_for(model)
        @events[model.id]
      end
    end

  end
end