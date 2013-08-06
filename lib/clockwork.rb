require 'logger'
require 'active_support/time'

require 'clockwork/at'
require 'clockwork/event'
require 'clockwork/manager'

module Clockwork
  extend self

  @@manager = Manager.new

  def configure(&block)
    @@manager.configure(&block)
  end

  def handler(&block)
    @@manager.handler(&block)
  end

  def every(period, job, options={}, &block)
    @@manager.every(period, job, options, &block)
  end

  def run
    @@manager.run
  end

  def clear!
    @@manager = Manager.new
  end
end

unless 1.respond_to?(:seconds)
  class Numeric
    def seconds; self; end
    alias :second :seconds

    def minutes; self * 60; end
    alias :minute :minutes

    def hours; self * 3600; end
    alias :hour :hours

    def days; self * 86400; end
    alias :day :days

    def weeks; self * 604800; end
    alias :week :weeks
  end
end
