require "minitest/autorun"
require 'clockwork/database_events/event_store'
require 'clockwork/database_events/event_collection'

describe Clockwork::DatabaseEvents::EventStore do

  described_class = Clockwork::DatabaseEvents::EventStore
  EventCollection = Clockwork::DatabaseEvents::EventCollection

  describe '#register' do
    it 'adds the event to the event group' do
      event_group = EventCollection.new
      EventCollection.stubs(:new).returns(event_group)

      event = OpenStruct.new
      model = OpenStruct.new id: 1
      subject = described_class.new(Proc.new {})

      event_group.expects(:add).with(event)

      subject.register(event, model)
    end
  end
end