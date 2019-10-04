module RSpec
  module Core
    module Formatters
      class ExceptionPresenter
        def find_failed_line
          line_regex = in_project_source_dir_regex(example)
          loaded_spec_files = RSpec.configuration.loaded_spec_files

          exception_backtrace.find do |line|
            next unless (line_path = line[/(.+?):(\d+)(|:\d+)/, 1])
            path = File.expand_path(line_path)  
            loaded_spec_files.include?(path) || path =~ line_regex
          end || exception_backtrace.first
        end

        def in_project_source_dir_regex(example)
          regexes = ::RSpec.configuration.project_source_dirs.map do |dir|
            /\A#{Regexp.escape(File.expand_path(example.metadata[:rails_root] + dir))}\//
          end
  
          Regexp.union(regexes)
        end
      end
    end
  end
end