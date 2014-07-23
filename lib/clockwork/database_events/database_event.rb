module Clockwork
  class DatabaseEvent < Event

    attr_accessor :sync_performer, :at

    def initialize(manager, period, job, block, sync_performer, options={})
      super(manager, period, job, block, options)
      @sync_performer = sync_performer
      @sync_performer.register(self)
    end

    def to_s
      job.name.to_s
    end

    def name_or_frequency_has_changed?(database_event)
      name_has_changed?(database_event) || frequency_has_changed?(database_event)
    end

    protected
    def name_has_changed?(database_event)
      name != database_event.name
    end

    def frequency_has_changed?(database_event)
      @period != database_event.frequency
    end
  end
end