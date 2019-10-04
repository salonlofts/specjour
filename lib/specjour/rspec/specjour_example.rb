module Specjour::RSpec
  class SpecjourExample < ::RSpec::Core::Example

    attr_reader :initial_metadata
    def initialize(metadata)
      @initial_metadata = metadata
      set_instance_variables(metadata)
    end


    def set_instance_variables(metadata_object)
      @example_group_class = fake_example_group_class
      @metadata = create_metadata_hash(metadata_object)
    end

    def fake_example_group_class
      OpenStruct.new(:metadata => {}, :ancestors => [], :parent_groups => [])
    end

    def create_metadata_hash(metadata_object)
      ::RSpec::Core::Metadata::ExampleHash.new( metadata_object,{},{},{}, ->{}).metadata
    end

    def location_rerun_argument
      metadata[:location]
    end

    def example_source
      metadata[:example_source]
    end

  end
end