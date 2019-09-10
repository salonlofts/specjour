module Specjour::RSpec
  class FinalReport
    attr_reader :examples
    attr_reader :duration

    def initialize
      @examples = []
      @duration = 0.0
      #::RSpec.configuration.color_enabled = true
      ::RSpec.configuration.output_stream = $stdout
    end

    def add(data)
      if data.respond_to?(:has_key?) && data.has_key?(:duration)
        self.duration = data[:duration]
      else
        add_example(data)
      end
    end

    def duration=(value)
      @duration = value.to_f if duration < value.to_f
    end

    def exit_status
      formatter.failed_examples.empty?
    end

    def add_example(metadata_collection)
      # new_examples = metadata_collection.map {|partial_metadata| create_example_from_metadata(partial_metadata)}
      new_examples = metadata_collection.map {|partial_metadata| SpecjourExample.new(partial_metadata)}
      examples.concat new_examples
    end

    #Refactored into SpecjourExample


    # def create_metadata_hash(metadata_object)
    #   ::RSpec::Core::Metadata::ExampleHash.new( metadata_object,{},{},{}, ->{}).metadata
    # end

    # def create_example_from_metadata(metadata_object)

    #   example = ::RSpec::Core::Example.allocate

    #   example.instance_variable_set(:@example_group_class,
    #     OpenStruct.new(:metadata => {}, :ancestors => [], :parent_groups => [])
    #   )

    #   mm =  create_metadata_hash(metadata_object)
    #   example.instance_variable_set(:@metadata, create_metadata_hash(metadata_object))
   
    #   example
    # end
     #end -- Refactoring into SpecjourExample

    def pending_examples
      examples.select {|e| e.execution_result[:status] == 'pending'}
    end

    def failed_examples
      examples.select {|e| e.execution_result[:status] == 'failed'}
    end

    def formatter
      @formatter ||= new_progress_formatter
    end

    def summarize
      if examples.size > 0
        formatter.start_dump(::RSpec::Core::Notifications::NullNotification)
        formatter.dump_pending(::RSpec::Core::Notifications::NullNotification)
        formatter.dump_failures(::RSpec::Core::Notifications::NullNotification)
        formatter.dump_summary(duration, examples.size, failed_examples.size, pending_examples.size)
      end
    end

    protected
    def new_progress_formatter
      new_formatter = ::RSpec::Core::Formatters::ProgressFormatter.new($stdout)
      new_formatter.instance_variable_set(:@failed_examples, failed_examples)
      new_formatter.instance_variable_set(:@pending_examples, pending_examples)
      new_formatter
    end
  end
end
