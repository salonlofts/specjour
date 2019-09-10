module Specjour
  module RSpec
    require 'rspec/core'
    require 'rspec/core/formatters/progress_formatter'

    require 'specjour/rspec/marshalable_exception'
    require 'specjour/rspec/preloader'
    require 'specjour/rspec/distributed_formatter'
    require 'specjour/rspec/final_report'
    require 'specjour/rspec/runner'
    require 'specjour/rspec/shared_example_group_ext'
    require 'specjour/rspec/specjour_example'
    require 'specjour/rspec/specjour_formatter'



    ::RSpec::Core::Runner.disable_autorun!
    ::RSpec::Core::Runner.class_eval "def self.trap_interrupt;end"
    ::RSpec.class_eval "def self.reset; world.reset; configuration.reset; end"
  end
end
