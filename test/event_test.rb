require File.expand_path('../../lib/clockwork', __FILE__)
require 'contest'

class EventTest < Test::Unit::TestCase
  describe "#thread?" do
    setup do
      @manager = mock
    end

    describe "manager config thread option set to true" do
      setup do
        @manager.stubs(:config).returns({ :thread => true })
      end

      test "is true" do
        event = Clockwork::Event.new(@manager, nil, nil, nil)
        assert_equal true, event.thread?
      end

      test "is false when event thread option set" do
        event = Clockwork::Event.new(@manager, nil, nil, nil, :thread => false)
        assert_equal false, event.thread?
      end
    end

    describe "manager config thread option not set" do
      setup do
        @manager.stubs(:config).returns({})
      end

      test "is true if thread option is specified with truthy value" do
        event = Clockwork::Event.new(@manager, nil, nil, nil, :thread => true)
        assert_equal true, event.thread?
      end


      test "coerces non-boolean truthy values to true" do
        event = Clockwork::Event.new(@manager, nil, nil, nil, { :thread => "anything that isn't nil or false" })
        assert_equal true, event.thread?
      end

      test "coerces non-boolean falsy values to false" do
        event = Clockwork::Event.new(@manager, nil, nil, nil, { :thread => nil })
        assert_equal false, event.thread?
      end
    end
  end
end
