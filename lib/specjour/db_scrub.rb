require 'pry'
# encoding: utf-8
module Specjour
  module DbScrub

    begin
      require 'rake'
      extend Rake::DSL if defined?(Rake::DSL)
      if defined?(Rails)
        Rake::Task.define_task(:environment) { }
        load 'rails/tasks/misc.rake'
        load 'active_record/railties/databases.rake'
      end
    rescue LoadError
      Specjour.logger.debug "Failed to load Rails rake tasks"
    end

    extend self

    def drop
      Rake::Task['db:drop'].invoke
    end

    def scrub
      connect_to_database
      puts "Resetting database #{ENV['TEST_ENV_NUMBER']}"
      
      if ActiveRecord::InternalMetadata[:environment].nil?
        p "ActiveRecord InternalMetadata environment not set.. setting now"
        Rake::Task['db:environment:set'].invoke
      end

      schema_load_task.invoke
    end

    protected

    def connect_to_database
      ActiveRecord::Base.remove_connection
      ActiveRecord::Tasks::DatabaseTasks.db_dir = Rails.application.config.paths["db"].first
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = Rails.application.paths['db/migrate'].to_a
      ActiveRecord::Tasks::DatabaseTasks.fixtures_path = File.join Rails.root, 'test', 'fixtures'
      ActiveRecord::Tasks::DatabaseTasks.root = Rails.root
      ActiveRecord::Base.configurations = Rails.application.config.database_configuration
      ActiveRecord::Base.establish_connection
      connection
    rescue # assume the database doesn't exist
      binding.pry
      Rake::Task['db:create'].invoke
    end

    def connection
      ActiveRecord::Base.connection
    end

    def pending_migrations?
      if Rails.version[/^3/]
        ActiveRecord::Migrator.new(:up, 'db/migrate').pending_migrations.any?
      else # Rails 4 version
        ActiveRecord::Migrator.needs_migration?
      end
    end

    def schema_load_task
      Rake::Task[{ :sql  => "db:test:load_structure", :ruby => "db:test:load" }[ActiveRecord::Base.schema_format]]
    end

    def tables_to_purge
      connection.tables - ['schema_migrations']
    end
  end
end
