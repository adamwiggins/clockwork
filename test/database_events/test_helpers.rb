# model instance factory - actually returns doubles
def model(options={})
  stub(options).tap do |model_instance|
    model_instance.stubs(:to_a).returns([model_instance])
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
  Time.new(now.year, now.month, now.day, now.hour, now.min + 1, 0)
end


def normalize_time t
  t.is_a?(String) ? Time.parse(t) : t
end