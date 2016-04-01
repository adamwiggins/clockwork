require_relative 'database_events/event'
require_relative 'database_events/synchronizer'
require_relative 'database_events/event_store'
require_relative 'database_events/manager'

# TERMINOLOGY
#
# For clarity, we have chosen to define terms as follows for better communication in the code, and when 
# discussing the database event implementation.
#
# "Event":      "Native" Clockwork events, whether Clockwork::Event or Clockwork::DatabaseEvents::Event
# "Model":      Database-backed model instances representing events to be created in Clockwork

module Clockwork

  module Methods
    def sync_database_events(options={}, &block)
      DatabaseEvents::Synchronizer.setup(options, &block)
    end
  end

  extend Methods

  module DatabaseEvents
  end
end
