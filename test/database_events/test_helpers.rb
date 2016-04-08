require_relative 'support/active_record_fake'

def setup_sync(options={})
  model_class = options.fetch(:model) { raise KeyError, ":model must be set to the model class" }
  frequency = options.fetch(:every) { raise KeyError, ":every must be set to the database sync frequency" }
  events_run = options.fetch(:events_run) { raise KeyError, ":events_run must be provided"}

  Clockwork::DatabaseEvents::Synchronizer.setup model: model_class, every: frequency do |model|
    name = model.respond_to?(:name) ? model.name : model.to_s
    events_run << name
  end
end

def assert_will_run(t)
  assert_equal 1, @manager.tick(normalize_time(t)).size
end

def assert_wont_run(t)
  assert_equal 0, @manager.tick(normalize_time(t)).size
end

def tick_at(now = Time.now, options = {})
  seconds_to_tick_for = options[:and_every_second_for] || 0
  number_of_ticks = 1 + seconds_to_tick_for
  number_of_ticks.times{|i| @manager.tick(now + i) }
end

def next_minute(now = Time.now)
  Time.at((now.to_i / 60 + 1) * 60)
end

def normalize_time t
  t.is_a?(String) ? Time.parse(t) : t
end


class DatabaseEventModel
  include ActiveRecordFake
  attr_accessor :name, :frequency, :at, :tz

  def name
    @name || "#{self.class}:#{id}"
  end
end

class DatabaseEventModel2
  include ActiveRecordFake
  attr_accessor :name, :frequency, :at, :tz

  def name
    @name || "#{self.class}:#{id}"
  end
end

class DatabaseEventModelWithoutName
  include ActiveRecordFake
  attr_accessor :frequency, :at
end

class DatabaseEventModelWithIf
  include ActiveRecordFake
  attr_accessor :name, :frequency, :at, :tz, :if_state

  def name
    @name || "#{self.class}:#{id}"
  end

  def if?(time)
    @if_state
  end
end