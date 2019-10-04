RSpec::Support.require_rspec_core "formatters/console_codes"
module Specjour::RSpec
  class SpecjourFormatter < ::RSpec::Core::Formatters::ProgressFormatter
    attr_reader :examples
    attr_accessor :duration

    def initialize(output,examples = [])
      @examples = examples
      @duration = 0
      super(output)
    end
    def add_examples(new_examples)
      examples.concat new_examples.reject{|example| example.execution_result.finished_at.nil?} # find out why workers are sending exampls that arn't finished
    end
    def summarize
      # start_dump(::RSpec::Core::Notifications::NullNotification)
      # dump_pending(::RSpec::Core::Notifications::NullNotification)
      # dump_failures(::RSpec::Core::Notifications::NullNotification)
      dump_failures(examples_notifications)
      # dump_summary(duration, examples.size, failed_examples.size, pending_examples.size)
      dump_summary ::RSpec::Core::Notifications::SummaryNotification.new(
        duration,  #duration
        examples, #examples
        failed_examples,  #failed_examples
        pending_examples, #pending_examples
        66, #load_time
        0 #errors_outside_of_examples_count
      )
    end

    def pending_examples
      examples.select {|e| e.execution_result[:status] == 'pending'}
    end

    def failed_examples
      examples.select {|e| e.execution_result[:status] == 'failed'}
    end
    def examples_notifications
      @examples_notifications ||= ::RSpec::Core::Notifications::ExamplesNotification.new(self)
    end

  end
end