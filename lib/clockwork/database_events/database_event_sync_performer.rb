class DatabaseEventSyncPerformer

    PERFORMERS = []

    def self.setup(options={}, &block)
      model_class = options.fetch(:model)
      every = options.fetch(:every)
      raise ArgumentError.new(":every must be greater or equal to 1.minute") if every < 1.minute

      sync_performer = DatabaseEventSyncPerformer.new(self, model_class, block)

      # create event that syncs clockwork events with events coming from database-backed model
      Clockwork.manager.every every, "sync_database_events_for_model_#{model_class}" do
        sync_performer.sync
      end
    end

    def initialize(manager, model_class, proc)
      @manager = manager
      @model_class = model_class
      @block = proc
      @database_event_registry = DatabaseEventRegistry.new(@manager, @block)

      PERFORMERS << self
    end

    # Ensure clockwork events reflect events from database-backed model
    # Adds any new events, modifies updated ones, and delets removed ones
    def sync
      model_ids_that_exist = []

      @model_class.all.each do |model|
        model_ids_that_exist << model.id
        unless are_different?(@database_event_registry.event_for(model), model)
          recreate_event(model)
        end
      end

      @database_event_registry.unregister_all_except(model_ids_that_exist)
    end

    protected

      def are_different?(event, model)
        return true if event.nil?
        event.name_or_frequency_has_changed?(model) || ats_have_changed?(model)
      end

      def ats_have_changed?(model)
        model_ats = ats_array_for_event(model)
        event_ats = ats_array_from_model(model)
        
        !model_ats.eql?(event_ats)
      end

      def ats_array_for_event(model)
        @database_event_registry[model.id].collect{|event| event.at }.compact
      end

      def ats_array_from_model(model)
        (at_strings_for(model) || []).collect{|at| At.parse(at) }
      end

      def at_strings_for(model)
        model.at.to_s.empty? ? nil : model.at.split(',').map(&:strip)
      end

      def recreate_event(model)
        @database_event_registry.unregister(model)

        options = {
          :from_database => true,
          :sync_performer => self,
          :at => at_strings_for(model)
        }

        # we pass actual model instance as the DbEvent's job, rather than just name
        @manager.every model.frequency, model, options, &@block
      end
  end