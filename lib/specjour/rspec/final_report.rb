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
        formatter.duration = data[:duration].to_f
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
      new_examples = metadata_collection.map {|partial_metadata| SpecjourExample.new(partial_metadata)}
      formatter.add_examples(new_examples)
      examples.concat new_examples
    end

    def formatter
      @formatter ||= SpecjourFormatter.new($stdout)
    end

    def summarize
      formatter.summarize
    end
  end
end
