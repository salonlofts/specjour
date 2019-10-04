module Specjour::RSpec
  class MarshalableException
    attr_accessor :message, :backtrace, :class_name, :cause

    def initialize(exception)
      self.class_name = exception.class.name
      self.message = exception.message
      self.cause = exception.cause
      self.backtrace = exception.backtrace
    end

    def class
      @class ||= OpenStruct.new :name => class_name
    end

    def pending_fixed?
      false
    end
  end
end
