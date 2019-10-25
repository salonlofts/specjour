module Specjour::RSpec
  class SpecjourExample < ::RSpec::Core::Example
    attr_reader :initial_metadata
    def initialize(metadata)
      @initial_metadata = metadata.dup
      set_instance_variables(metadata)
      clear_procs
    end
    #TODO clean me up --spd
    def clear_procs # so we can marshal
      @metadata[:example_source] = @initial_metadata[:block].try(:source)
      @initial_metadata[:block] = nil
      @metadata[:block] = nil
      @initial_metadata[:block] = nil
      @metadata[:example_group][:block] = nil if @metadata[:example_group].present?
      @initial_metadata[:example_group][:block] = nil if @initial_metadata[:example_group].present?

      @metadata[:example_group] = dumpable_hash(@metadata[:example_group]) if @metadata[:example_group].present?
      @initial_metadata[:example_group] = dumpable_hash(@initial_metadata[:example_group]) if @initial_metadata[:example_group].present?
      @metadata = dumpable_hash(@metadata)
      @initial_metadata = dumpable_hash(@initial_metadata)
    end

    def dumpable_hash(h)
      return h unless h.default_proc
      copy = h.clone  
      copy.default = nil # clear the default_proc
      copy
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