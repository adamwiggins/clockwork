module Clockwork

  # add equality testing to At
  class At
    attr_reader :min, :hour, :wday

    def == other
      @min == other.min && @hour == other.hour && @wday == other.wday
    end
  end

  module Methods
    def sync_database_tasks(options={}, &block)
      Clockwork.manager.sync_database_tasks(options, &block)
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

    # Ensure clockwork events reflect database tasks
    # Adds any new tasks, modifies updated ones, and delets removed ones
    def sync
      model_ids_that_exist = []

      @model.all.each do |db_task|
        model_ids_that_exist << db_task.id
        
        if !event_exists_for_task(db_task) || task_has_changed(db_task)
          recreate_event_for_database_task(db_task)
        end
      end

      remove_deleted_database_tasks(model_ids_that_exist)
    end

    def clockwork_events
      @events.values.flatten
    end

    # store events by task_id in array (array is needed as there is 1 event per At)
    def add_event(e, task_id)
      @events[task_id] ||= []
      @events[task_id] << e
    end

    protected

      def recreate_event_for_database_task(db_task)
        @events[db_task.id] = nil

        options = { 
          :from_database => true, 
          :db_task_id =>  db_task.id,
          :performer => self,
          :at => array_of_ats_for(db_task, :nil_if_empty => true)
        }

        @manager.every db_task.frequency, db_task.name, options, &@block
      end

      def event_exists_for_task(db_task)
        @events[db_task.id]
      end

      def remove_deleted_database_tasks(model_ids_that_exist)
        @events.reject!{|db_task_id, _| !model_ids_that_exist.include?(db_task_id) }
      end

      def task_has_changed(task)
        events = @events[task.id]
        event = @events[task.id].first # all events will have same frequency/name, just different ats
        ats_for_task = array_of_ats_for(task)
        ats_from_event = array_of_ats_from_event(task.id)

        name_has_changed = task.name != event.job
        frequency_has_changed = task.frequency != event.instance_variable_get(:@period)

        at_has_changed = ats_for_task.length != ats_from_event.length
        at_has_changed ||= ats_for_task.inject(false) do |memo, at|
          memo ||= !ats_from_event.include?(At.parse(at))
        end

        name_has_changed || frequency_has_changed || at_has_changed
      end

      def array_of_ats_from_event(task_id)
        @events[task_id].collect{|clockwork_event| clockwork_event.instance_variable_get(:@at) }.compact
      end

      def array_of_ats_for(task, opts={})
        if task.at.to_s.empty?
          opts[:nil_if_empty] ? nil : []
        else
          task.at.split(',').map(&:strip)
        end
      end
  end

  class ManagerWithDatabaseTasks < Manager

    def initialize
      super
      @database_event_sync_performers = []
    end

    def sync_database_tasks(options={}, &block)
      [:model, :every].each do |option|
        raise ArgumentError.new("requires :#{option} option") unless options.include?(option)
      end
      raise ArgumentError.new(":every must be greater or equal to 1.minute") if options[:every] < 1.minute

      sync_performer = DatabaseEventSyncPerformer.new(self, options[:model], block)
      @database_event_sync_performers << sync_performer

      # create event that syncs clockwork events with database events
      every options[:every], "sync_database_tasks_for_model_#{options[:model]}" do
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
          options[:performer].add_event(e, options[:db_task_id])
        else
          @events << e
        end
      end
    end
  end
end
