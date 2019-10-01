class Specjour::RSpec::Preloader
  def self.load(paths=[])
    Specjour.benchmark("Loading RSpec environment") do
      p "loading: #{paths}"
      Specjour.benchmark("Loading spec helper environment") do
        require File.expand_path('spec/spec_helper', Dir.pwd)
      end
      Specjour.benchmark("Loading spec files") do
        load_spec_files paths
      end
    end
  end

  def self.load_spec_files(paths)
    options = ::RSpec::Core::ConfigurationOptions.new(paths)
    options.configure ::RSpec.configuration
    ::RSpec.configuration.load_spec_files
  end
end
