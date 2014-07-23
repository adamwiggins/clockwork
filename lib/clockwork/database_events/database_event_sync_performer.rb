class DatabaseEventSyncPerformer

    PERFORMERS = []

    def self.setup(options={}, &block)
      model = options.fetch(:model)
      every = options.fetch(:every)
      raise ArgumentError.new(":every must be greater or equal to 1.minute") if every < 1.minute

      sync_performer = DatabaseEventSyncPerformer.new(self, model, block)

      # create event that syncs clockwork events with database events
      Clockwork.manager.every options[:every], "sync_database_events_for_model_#{options[:model]}" do
        sync_performer.sync
      end
    end

    def initialize(manager, model, proc)
      @manager = manager
      @model = model
      @block = proc
      @events = {}

      PERFORMERS << self
    end

    # Ensure clockwork events reflect database events
    # Adds any new events, modifies updated ones, and delets removed ones
    def sync
      model_ids_that_exist = []

      @model.all.each do |db_event|
        model_ids_that_exist << db_event.id
        
        clockwork_event = clockwork_event_for(db_event)
        recreate_clockwork_event(db_event) if !clockwork_event || has_changed?(clockwork_event, db_event)
      end

      remove_deleted_db_events(model_ids_that_exist)
    end

    def register(db_event)
      (@events[db_event.id] ||= []) << db_event
    end

    protected

      def has_changed?(clockwork_event, db_event)
        clockwork_event.name_or_frequency_has_changed?(db_event) || ats_have_changed?(db_event)
      end

      def ats_have_changed?(database_event)
        database_event_ats = array_of_ats_for(database_event)
        clockwork_event_ats = array_of_ats_from_clockwork_event(database_event.id)
        
        database_event_ats.eql?(clockwork_event_ats)
      end

      def array_of_ats_from_clockwork_event(db_event_id)
        @events[db_event_id].collect{|clockwork_event| clockwork_event.at }.compact
      end

      def array_of_ats_for(database_event)
        (at_strings_for(database_event) || []).collect{|at| At.parse(at) }
      end

      def at_strings_for(db_event, opts={})
        db_event.at.to_s.empty? ? nil : db_event.at.split(',').map(&:strip)
      end

      def unregister_clockwork_events_for(db_event)
        @events[db_event.id].each{|e| @manager.unregister(e) }
      end

      def recreate_clockwork_event(db_event)
        unregister_clockwork_events_for(db_event)
        @events[db_event.id] = nil

        options = {
          :from_database => true,
          :db_event_id =>  db_event.id,
          :sync_performer => self,
          :at => at_strings_for(db_event)
        }

        # we pass actual db_event as the DbEvent's job, rather than just name
        @manager.every db_event.frequency, db_event, options, &@block
      end

      # all events of same id will have same frequency/name, just different ats
      def clockwork_event_for(db_event)
        @events[db_event.id].first
      end

      def remove_deleted_db_events(model_ids_that_exist)
        (@events.keys - model_ids_that_exist).each do |id|
          unregister_clockwork_events_for(@events[id])
        end

        @events.keep_if{|db_event_id| model_ids_that_exist.include?(db_event_id) }
      end
  end