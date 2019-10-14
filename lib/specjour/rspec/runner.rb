module Specjour::RSpec::Runner
  ::RSpec.configuration.backtrace_exclusion_patterns << %r(lib/specjour/)

  def self.run(spec, output)
    Specjour.logger.debug  '------------------in Specjour::Runner.run---------------'
    Specjour.logger.debug  spec

    if spec.include?('--description')
      location = spec.split('--description')[0]
      full_description = spec.split('--description')[1]
      args = ['--format=Specjour::RSpec::WorkerFormatter',location,  "-e#{full_description}"]
    else
      args = ['--format=Specjour::RSpec::WorkerFormatter',spec]
    end
    Specjour.logger.debug "----rspec args=#{args}"

    Specjour.logger.debug 'before rspec core run'
    ::RSpec::Core::Runner.run args, $stderr, output 
    Specjour.logger.debug  'after  rspec core run'


    ensure
      Specjour.logger.debug 'in runner ensure'
      ::RSpec.configuration.filter_manager = ::RSpec::Core::FilterManager.new
      ::RSpec.world.ordered_example_groups.clear
      ::RSpec.world.filtered_examples.clear
      ::RSpec.world.inclusion_filter.clear
      ::RSpec.world.exclusion_filter.clear
      ::RSpec.world.send(:instance_variable_set, :@line_numbers, nil)
  end
end