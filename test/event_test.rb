require File.expand_path('../../lib/clockwork', __FILE__)
require "minitest/autorun"

describe Clockwork::Event do
  describe '#thread?' do
    before do
      @manager = Class.new
    end

    describe 'manager config thread option set to true' do
      before do
        @manager.stubs(:config).returns({ :thread => true })
      end

      it 'is true' do
        event = Clockwork::Event.new(@manager, nil, nil, nil)
        assert_equal true, event.thread?
      end

      it 'is false when event thread option set' do
        event = Clockwork::Event.new(@manager, nil, nil, nil, :thread => false)
        assert_equal false, event.thread?
      end
    end

    describe 'manager config thread option not set' do
      before do
        @manager.stubs(:config).returns({})
      end

      it 'is true if event thread option is true' do
        event = Clockwork::Event.new(@manager, nil, nil, nil, :thread => true)
        assert_equal true, event.thread?
      end
    end
  end
end
