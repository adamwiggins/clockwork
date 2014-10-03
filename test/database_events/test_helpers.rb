def setup_sync(options={})
  model_class = options.fetch(:model) { raise KeyError, ":model must be set to the model class" }
  frequency = options.fetch(:every) { raise KeyError, ":every must be set to the database sync frequency" }
  events_run = options.fetch(:events_run) { raise KeyError, ":events_run must be provided"}

  Clockwork::DatabaseEvents::SyncPerformer.setup model: model_class, every: frequency do |model|
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


class ActiveRecordFake
  attr_accessor :id, :at, :frequency, :tz

  class << self
    def create *args
      new *args
    end

    def add instance
      @events << instance
    end

    def remove instance
      @events.delete(instance)
    end

    def next_id
      id = @next_id
      @next_id += 1
      id
    end

    def reset_id
      @next_id = 1
    end

    def delete_all
      @events.clear
      reset_id
    end

    def all
      @events.dup
    end
  end

  def initialize options={}
    @id = options.fetch(:id) { self.class.next_id }
    @at = options.fetch(:at) { nil }        
    @frequency = options.fetch(:frequency) { raise KeyError, ":every must be supplied" }
    @tz = options.fetch(:tz) { nil }

    self.class.add self
  end

  def delete!
    self.class.remove(self)
  end

  def update options={}
    options.each{|attr, value| self.send("#{attr}=".to_sym, value) }
  end
end

class DatabaseEventModelClass < ActiveRecordFake
  attr_accessor :name

  @events = []
  @next_id = 1

  def initialize options={}
    super(options.reject{|key, value| key == :name})
    @name = options.fetch(:name) { nil }
  end

  def name
    @name || "#{self.class}:#{id}"
  end
end

class DatabaseEventModelClass2 < ActiveRecordFake
  attr_accessor :name

  @events = []
  @next_id = 1

  def initialize options={}
    super(options.reject{|key, value| key == :name})
    @name = options.fetch(:name) { nil }
  end

  def name
    @name || "#{self.class}:#{id}"
  end
end

class DatabaseEventModelClassWithoutName < ActiveRecordFake
  @events = []
  @next_id = 1
end