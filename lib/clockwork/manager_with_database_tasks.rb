module Clockwork

  # add equality testing to At
  class At
    attr_reader :min, :hour, :wday

    def == other
      @min == other.min && @hour == other.hour && @wday == other.wday
    end
  end

  module Methods
    alias :sync_database_tasks, :sync_database_events

    def sync_database_events(options={}, &block)
      Clockwork.manager.sync_database_events(options, &block)
    end
  end

  extend Methods

  class DatabaseEventSyncPerformer

    def initialize(manager, model, proc)
      @manager = manager
      @model = model
      @block = proc
      @events = {}
    end

    # Ensure clockwork events reflect database events
    # Adds any new events, modifies updated ones, and delets removed ones
    def sync
      model_ids_that_exist = []

      @model.all.each do |db_event|
        model_ids_that_exist << db_event.id
        
        if !clockwork_event_exists_for_db_event(db_event) || db_event_has_changed(db_event)
          recreate_clockwork_event_for_db_event(db_event)
        end
      end

      remove_deleted_db_events(model_ids_that_exist)
    end

    def clockwork_events
      @events.values.flatten
    end

    # store events by database event id in array (array is needed as there is 1 event per At)
    def add_event(e, db_event_id)
      @events[db_event_id] ||= []
      @events[db_event_id] << e
    end

    protected

      def recreate_clockwork_event_for_db_event(db_event)
        @events[db_event.id] = nil

        options = { 
          :from_database => true, 
          :db_event_id =>  db_event.id,
          :performer => self,
          :at => array_of_ats_for(db_event, :nil_if_empty => true)
        }

        if db_event.respond_to?(:tz)
          options[:tz] = db_event.tz
        end

        @manager.every db_event.frequency, db_event.name, options, &@block
      end

      def clockwork_event_exists_for_db_event(db_event)
        @events[db_event.id]
      end

      def remove_deleted_db_events(model_ids_that_exist)
        @events.reject!{|db_event_id, _| !model_ids_that_exist.include?(db_event_id) }
      end

      def db_event_has_changed(db_event)
        events = @events[db_event.id]
        clockwork_event = @events[db_event.id].first # all events will have same frequency/name, just different ats
        ats_for_db_event = array_of_ats_for(db_event)
        ats_from_clockwork_event = array_of_ats_from_clockwork_event(db_event.id)

        name_has_changed = db_event.name != clockwork_event.job
        frequency_has_changed = db_event.frequency != clockwork_event.instance_variable_get(:@period)

        at_has_changed = ats_for_db_event.length != ats_from_clockwork_event.length
        at_has_changed ||= ats_for_db_event.inject(false) do |memo, at|
          memo ||= !ats_from_clockwork_event.include?(At.parse(at))
        end

        name_has_changed || frequency_has_changed || at_has_changed
      end

      def array_of_ats_from_clockwork_event(db_event_id)
        @events[db_event_id].collect{|clockwork_event| clockwork_event.instance_variable_get(:@at) }.compact
      end

      def array_of_ats_for(db_event, opts={})
        if db_event.at.to_s.empty?
          opts[:nil_if_empty] ? nil : []
        else
          db_event.at.split(',').map(&:strip)
        end
      end
  end

  class ManagerWithDatabaseEvents < Manager

    def initialize
      super
      @database_event_sync_performers = []
    end

    def sync_database_db_events(options={}, &block)
      [:model, :every].each do |option|
        raise ArgumentError.new("requires :#{option} option") unless options.include?(option)
      end
      raise ArgumentError.new(":every must be greater or equal to 1.minute") if options[:every] < 1.minute

      sync_performer = DatabaseEventSyncPerformer.new(self, options[:model], block)
      @database_event_sync_performers << sync_performer

      # create event that syncs clockwork events with database events
      every options[:every], "sync_database_events_for_model_#{options[:model]}" do
        sync_performer.sync
      end
    end

    private

    def events_from_database_as_array
      @database_event_sync_performers.collect{|performer| performer.clockwork_events}.flatten
    end

    def events_to_run(t)
      (@events + events_from_database_as_array).select{|event| event.run_now?(t) }
    end

    def register(period, job, block, options)
      Event.new(self, period, job, block || handler, options).tap do |e|
        if options[:from_database]
          options[:performer].add_event(e, options[:db_event_id])
        else
          @events << e
        end
      end
    end
  end
end
