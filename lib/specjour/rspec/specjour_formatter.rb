module Specjour::RSpec
  class SpecjourFormatter < ::RSpec::Core::Formatters::ProgressFormatter
    ::RSpec::Core::Formatters.register self, :example_passed, :example_pending, :example_failed, :start_dump

    def metadata_for_examples
      return [] if example_group.nil?  #FIX ME THIS SHOULDNT HAPPEN
      example_group.examples.map do |example|
        metadata = example.metadata
        {
          :execution_result => marshalable_execution_result(example.execution_result),
          :description      => metadata[:description],
          :file_path        => metadata[:file_path],
          :full_description => metadata[:full_description],
          :line_number      => metadata[:line_number],
          :location         => metadata[:location],
          :run_time         => example.execution_result.run_time,
          :hostname         => `hostname`.strip,
          :worker_number    => ENV['TEST_ENV_NUMBER']
        }
      end

    end

    def noop(*args)
    end
    alias dump_pending noop
    alias dump_failures noop
    alias start_dump noop
    alias message noop

    def color_enabled?
      true
    end

    def dump_summary(*args)
      output.send_message :rspec_summary=, metadata_for_examples
    end

    def close(notification=nil)
      # examples.clear
      if @output_hash
        @output_hash[:examples].each do |e|
          e[:hostname] = hostname
          e[:worker_number] = ENV["TEST_ENV_NUMBER"]
          @output.report_test(e)
        end
      end
      super(notification)
    end

    protected

    def marshalable_execution_result(execution_result)
      if exception = execution_result.exception
        execution_result.exception = MarshalableException.new(exception)
      end
      if pending_exception = execution_result.pending_exception
        execution_result.pending_exception = MarshalableException.new(pending_exception)
      end

      execution_result.started_at = Time.at(execution_result.started_at) rescue nil #BROKEN take me out
      execution_result.finished_at = Time.at(execution_result.finished_at) rescue nil #BROKEN take me out
      execution_result
    end

  end
end
