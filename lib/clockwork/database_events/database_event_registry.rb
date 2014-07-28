module Clockwork

  class DatabaseEventRegistry

    def initialize
      @events = {}
    end

    def register(model)
      (@events[model.id] ||= []) << model
    end

    # Unregisters an event, or set of events by id
    # 
    # arg     either single id, or array of ids
    def unregister(arg)
      ids_to_unregister = arg.to_a

      ids_to_unregister.each do |id|
        @events[id].each{|e| @manager.unregister(e) }
        @events[id] = nil
      end
    end

    def unregister_all_except(ids)
      unregister(@events.keys - ids)
    end

    # all events of same id will have same frequency/name, just different ats
    def event_for(model)
      @events[model.id].first
    end
  end
end