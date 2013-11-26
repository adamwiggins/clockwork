require File.expand_path('../../lib/clockwork', __FILE__)
require 'contest'

class EventTest < Test::Unit::TestCase
  describe "#thread?" do
    test "it should coerce non-boolean truthy values to true" do
      manager = mock
      manager.stubs(:config).returns({})
      event = Clockwork::Event.new(manager, nil, nil, nil, {thread: "anything that isn't nil or false"})
      assert_equal true, event.thread?
    end

    test "it should coerce non-boolean falsy values to false" do
      manager = mock
      manager.stubs(:config).returns({})
      event = Clockwork::Event.new(manager, nil, nil, nil, {thread: nil})
      assert_equal false, event.thread?
    end
  end
end
