require File.expand_path('../../lib/clockwork', __FILE__)
require 'rubygems'
require 'contest'
require 'mocha/setup'
require 'time'
require 'active_support/time'

class AtTest < Test::Unit::TestCase
  def time_in_day(hour, minute)
    Time.new(2013, 1, 1, hour, minute, 0)
  end

  test '16:20' do
    at = Clockwork::At.parse('16:20')
    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  test '8:20' do
    at = Clockwork::At.parse('8:20')
    assert !at.ready?(time_in_day(8, 19))
    assert  at.ready?(time_in_day(8, 20))
    assert !at.ready?(time_in_day(8, 21))
  end

  test '**:20' do
    at = Clockwork::At.parse('**:20')

    assert !at.ready?(time_in_day(15, 19))
    assert  at.ready?(time_in_day(15, 20))
    assert !at.ready?(time_in_day(15, 21))

    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  test '**:20' do
    at = Clockwork::At.parse('*:20')

    assert !at.ready?(time_in_day(15, 19))
    assert  at.ready?(time_in_day(15, 20))
    assert !at.ready?(time_in_day(15, 21))

    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  test 'Saturday 12:00' do
    at = Clockwork::At.parse('Saturday 12:00')

    assert !at.ready?(Time.new(2010, 1, 1, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 2, 12, 00)) # Saturday
    assert !at.ready?(Time.new(2010, 1, 3, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 9, 12, 00))
  end

  test 'Saturday 12:00' do
    at = Clockwork::At.parse('sat 12:00')

    assert !at.ready?(Time.new(2010, 1, 1, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 2, 12, 00))
    assert !at.ready?(Time.new(2010, 1, 3, 12, 00))
  end
end
