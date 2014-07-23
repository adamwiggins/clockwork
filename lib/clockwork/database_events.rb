require 'database_events/database_event'
require 'database_events/database_event_sync_performer'
require 'database_events/manager'

module Clockwork

  # add equality testing to At
  class At
    attr_reader :min, :hour, :wday

    def == other
      @min == other.min && @hour == other.hour && @wday == other.wday
    end
  end

  module Methods
    # maintain backwards compatibility
    alias :sync_database_tasks, :sync_database_events

    def sync_database_events(options={}, &block)
      DatabaseEventSyncPerformer.setup(options, &block)
    end
  end

  extend Methods
end
