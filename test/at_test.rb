require File.expand_path('../../lib/clockwork', __FILE__)
require "minitest/autorun"
require 'mocha/setup'
require 'time'
require 'active_support/time'

describe 'Clockwork::At' do
  def time_in_day(hour, minute)
    Time.new(2013, 1, 1, hour, minute, 0)
  end

  it '16:20' do
    at = Clockwork::At.parse('16:20')
    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  it '8:20' do
    at = Clockwork::At.parse('8:20')
    assert !at.ready?(time_in_day(8, 19))
    assert  at.ready?(time_in_day(8, 20))
    assert !at.ready?(time_in_day(8, 21))
  end

  it '**:20 with two stars' do
    at = Clockwork::At.parse('**:20')

    assert !at.ready?(time_in_day(15, 19))
    assert  at.ready?(time_in_day(15, 20))
    assert !at.ready?(time_in_day(15, 21))

    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  it '*:20 with one star' do
    at = Clockwork::At.parse('*:20')

    assert !at.ready?(time_in_day(15, 19))
    assert  at.ready?(time_in_day(15, 20))
    assert !at.ready?(time_in_day(15, 21))

    assert !at.ready?(time_in_day(16, 19))
    assert  at.ready?(time_in_day(16, 20))
    assert !at.ready?(time_in_day(16, 21))
  end

  it '16:**' do
    at = Clockwork::At.parse('16:**')

    assert !at.ready?(time_in_day(15, 59))
    assert  at.ready?(time_in_day(16, 00))
    assert  at.ready?(time_in_day(16, 30))
    assert  at.ready?(time_in_day(16, 59))
    assert !at.ready?(time_in_day(17, 00))
  end

  it '8:**' do
    at = Clockwork::At.parse('8:**')

    assert !at.ready?(time_in_day(7, 59))
    assert  at.ready?(time_in_day(8, 00))
    assert  at.ready?(time_in_day(8, 30))
    assert  at.ready?(time_in_day(8, 59))
    assert !at.ready?(time_in_day(9, 00))
  end

  it 'Saturday 12:00' do
    at = Clockwork::At.parse('Saturday 12:00')

    assert !at.ready?(Time.new(2010, 1, 1, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 2, 12, 00)) # Saturday
    assert !at.ready?(Time.new(2010, 1, 3, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 9, 12, 00))
  end

  it 'sat 12:00' do
    at = Clockwork::At.parse('sat 12:00')

    assert !at.ready?(Time.new(2010, 1, 1, 12, 00))
    assert  at.ready?(Time.new(2010, 1, 2, 12, 00))
    assert !at.ready?(Time.new(2010, 1, 3, 12, 00))
  end

  it 'invalid time 32:00' do
    assert_raises Clockwork::At::FailedToParse do
      Clockwork::At.parse('32:00')
    end
  end

  it 'invalid multi-line with Sat 12:00' do
    assert_raises Clockwork::At::FailedToParse do
      Clockwork::At.parse("sat 12:00\nreally invalid time")
    end
  end

  it 'invalid multi-line with 8:30' do
    assert_raises Clockwork::At::FailedToParse do
      Clockwork::At.parse("8:30\nreally invalid time")
    end
  end

  it 'invalid multi-line with *:10' do
    assert_raises Clockwork::At::FailedToParse do
      Clockwork::At.parse("*:10\nreally invalid time")
    end
  end

  it 'invalid multi-line with 12:**' do
    assert_raises Clockwork::At::FailedToParse do
      Clockwork::At.parse("12:**\nreally invalid time")
    end
  end
end
