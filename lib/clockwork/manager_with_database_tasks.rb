module Clockwork
  class ManagerWithDatabaseTasks < Manager

    SECOND_TO_RUN_DATABASE_SYNC_AT = 0

    def initialize
    	super
    	@events_from_database = []
      @next_sync_database_tasks_identifier = 0
    end

    def sync_database_tasks(options={}, &block)
     	[:model, :every].each do |option|
     		raise ArgumentError.new("requires :#{option} option") unless options.include?(option)
     	end
      raise ArgumentError.new(":every must be greater or equal to 1.minute") if options[:every] < 1.minute

     	
     	model = options[:model]
     	frequency = options[:every]
      sync_task_id = get_sync_task_id

      # Prevent database tasks from running in same cycle as the database sync, 
      # as this can lead to the same task being run twice
      options_to_run_database_sync_in_own_cycle  = { :if => lambda { |t| t.sec == SECOND_TO_RUN_DATABASE_SYNC_AT } }

      # create event that syncs clockwork events with database events
     	every frequency, "sync_database_tasks_for_model_#{model}", options_to_run_database_sync_in_own_cycle do
	     	reload_events_from_database sync_task_id, model, &block
     	end
  	end


    protected

    # sync_task_id's are used to group the database events from a particular sync_database_tasks call
    # This method hands out the ids, incrementing the id to keep them unique. 
    def get_sync_task_id
      current_sync_task_id = @next_sync_database_tasks_identifier
      @next_sync_database_tasks_identifier += 1
      current_sync_task_id
    end

    def reload_events_from_database(sync_task_id, model, &block)
    	@events_from_database[sync_task_id] = []

	    model.all.each do |db_task|
	      options = { from_database: true, :sync_task_id => sync_task_id }
	      options[:at] = db_task.at.split(',') unless db_task.at.blank?

        # If database tasks can be scheduled in same clock cycle that database syncs occur
        # then previous copy of database sync task will be stored and set to run (in #tick events variable)
        # *before* we then delete all database tasks. This causes the task to be run at HH:00 (previous copy)
        # and at HH:01 (newly fetched copy).
        option_to_prevent_database_tasks_running_in_same_cycle_as_sync = { :if => lambda{|t| t.sec != SECOND_TO_RUN_DATABASE_SYNC_AT } }
	      every db_task.frequency, 
              db_task.name, 
              options.merge(option_to_prevent_database_tasks_running_in_same_cycle_as_sync), 
              &block
	    end
    end

    private

    def events_to_run(t)
      (@events + @events_from_database.flatten).select{|event| event.run_now?(t) }
    end

    def register(period, job, block, options)
      event = Event.new(self, period, job, block || handler, options)
      if options[:from_database]
      	@events_from_database[options[:sync_task_id]] << event
      else
	      @events << event
	    end
      event
    end
  end
end
