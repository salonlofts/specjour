RSpec::Support.require_rspec_core "formatters/console_codes"
module Specjour::RSpec
  class SpecjourFormatter < ::RSpec::Core::Formatters::ProgressFormatter
    attr_reader :examples
    def initialize(output,examples)
      @examples = examples
      super(output)
    end

    def summarize
      # start_dump(::RSpec::Core::Notifications::NullNotification)
      # dump_pending(::RSpec::Core::Notifications::NullNotification)
      # dump_failures(::RSpec::Core::Notifications::NullNotification)
      # dump_summary(duration, examples.size, failed_examples.size, pending_examples.size)
      dump_summary ::RSpec::Core::Notifications::SummaryNotification.new(
        55,  #duration
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

  end
end