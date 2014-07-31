require_relative 'database_events/event'
require_relative 'database_events/sync_performer'
require_relative 'database_events/registry'
require_relative 'database_events/manager'

# TERMINOLOGY
#
# For clarity, we have chosen to define terms as follows for better communication in the code, and when 
# discussing the database event implementation.
#
# "Event":      "Native" Clockwork events, whether Clockwork::Event or Clockwork::DatabaseEvents::Event
# "Model":      Database-backed model instances representing events to be created in Clockwork

# add equality testing to At
module Clockwork
  class At
    attr_reader :min, :hour, :wday

    def == other
      @min == other.min && @hour == other.hour && @wday == other.wday
    end
  end

  module Methods
    def sync_database_events(options={}, &block)
      DatabaseEvents::SyncPerformer.setup(options, &block)
    end

    # maintain backwards compatibility
    alias :sync_database_tasks :sync_database_events
  end

  extend Methods

  module DatabaseEvents
  end
end