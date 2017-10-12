module Specjour
  class Dispatcher
    require 'dnssd'
    Thread.abort_on_exception = true
    include SocketHelper

    attr_reader :project_alias, :managers, :manager_threads, :hosts, :options, :drb_connection_errors, :test_paths, :rsync_port
    attr_accessor :worker_size, :project_path

    def initialize(options = {})
      Specjour.load_custom_hooks
      @options = options
      @project_path = options[:project_path]
      @test_paths = options[:test_paths]
      @worker_size = 0
      @managers = []
      @drb_connection_errors = Hash.new(0)
      @rsync_port = options[:rsync_port]
      @manager_threads = []
    end

    def start
      abort("#{project_path} doesn't exist") unless File.directory?(project_path)
      gather_managers
      rsync_daemon.start
      dispatch_work
      if dispatching_tests?
        printer.start
      else
        wait_on_managers
      end
      exit_status = printer.exit_status

      Configuration.after_completion.call

      if exit_status
        Configuration.after_success.call
      else
        Configuration.after_failure.call
      end

      exit printer.exit_status
    end

    protected

    def add_manager(manager)
      set_up_manager(manager)
      managers << manager
      self.worker_size += manager.worker_size
    end

    def command_managers(&block)
      managers.each do |manager|
        manager_threads << Thread.new(manager, &block)
      end
    end

    def dispatcher_uri
      @dispatcher_uri ||= URI::Generic.build :scheme => "specjour", :host => local_ip, :port => printer.port
    end

    def dispatch_work
      puts "#{worker_size} workers found: " +
        managers.map { |manager| "#{manager.hostname}--#{manager.__drburi}:(#{manager.worker_size})" }.join(', ')
      command_managers { |m|
        puts "Dispatching to #{m.hostname}:--#{m.__drburi}..."
        m.dispatch rescue DRb::DRbConnError
      }
    end

    def dispatching_tests?
      worker_task == 'run_tests'
    end

    def fetch_manager(uri)
      manager = DRbObject.new_with_uri(uri.to_s)
      if !managers.include?(manager) && manager.available_for?(project_alias)
        if !managers.map(&:__drburi).include?(manager.__drburi)
          add_manager(manager)
        else
          Specjour.logger.debug "skipping #{manager.hostname} because it has already been included"
        end
      end
    rescue DRb::DRbConnError => e
      drb_connection_errors[uri] += 1
      Specjour.logger.debug "#{e.message}: couldn't connect to manager at #{uri}"
      sleep(0.1) && retry if drb_connection_errors[uri] < 5
    end

    def fetch_manager_from_uri(uri)
      manager = DRbObject.new_with_uri(uri.to_s)
      if !managers.include?(manager) && manager.available_for?(project_alias)
        if !managers.map(&:__drburi).include?(manager.__drburi)
          manager
        else
          Specjour.logger.debug "skipping #{manager.hostname} because it has already been included"
          nil
        end
      end
    rescue DRb::DRbConnError => e
      drb_connection_errors[uri] += 1
      Specjour.logger.debug "#{e.message}: couldn't connect to manager at #{uri}"
      sleep(0.1) && retry if drb_connection_errors[uri] < 5
    end

    def fork_local_manager
      puts "No listeners found on this machine, starting one..."
      manager_options = {:worker_size => options[:worker_size], :registered_projects => [project_alias], :rsync_port => rsync_port}
      manager = Manager.start_quietly manager_options
      Process.detach manager.pid
      fetch_manager(manager.drb_uri)
      at_exit do
        unless Specjour.interrupted?
          Process.kill('TERM', manager.pid) rescue Errno::ESRCH
        end
      end
    end

    def gather_managers
      puts "Looking for listeners(experimental)..."
      gather_remote_managers
      fork_local_manager if local_manager_needed?
      abort "No listeners found" if managers.size.zero?
    end

    def gather_remote_managers
      replies = []
      Timeout.timeout(1) do
        DNSSD.browse!('_druby._tcp') do |reply|
          replies << reply if reply.flags.add?
        end
        raise Timeout::Error
      end
    rescue Timeout::Error
      replies.each {|r| resolve_reply(r)}
    end

    def gather_remote_manager_replies
      replies = []
      Timeout.timeout(1) do
        DNSSD.browse!('_druby._tcp') do |reply|
          replies << reply if reply.flags.add?
        end
        raise Timeout::Error
      end
    rescue Timeout::Error
      replies
    end

    def local_manager_needed?
      options[:worker_size] > 0 && no_local_managers?
    end

    def no_local_managers?
      managers.none? {|m| m.local_ip == local_ip}
    end

    def printer
      @printer ||= Printer.new
    end

    def project_alias
      @project_alias ||= options[:project_alias] || project_name
    end

    def project_name
      @project_name ||= File.basename(project_path)
    end

    def find_more_managers
      puts "finding more managers"
      new_managers = []
      replies = gather_remote_manager_replies
      uris = replies.map{|reply| resolve_reply_to_uri(reply)}
      new_managers = uris.each{|uri| fetch_manager_from_uri(uri)}
      new_managers.each do |manager|
        set_up_manager(manager)
        puts "adding new manager #{manager}"
        managers << manager
        self.worker_size += manager.worker_size
        puts "worker size now #{self.worker_size}"
      end
    end

    def resolve_reply(reply)
      Timeout.timeout(1) do
        DNSSD.resolve!(reply.name, reply.type, reply.domain, flags=0, reply.interface) do |resolved|
          Specjour.logger.debug "Bonjour discovered #{resolved.target}"
          if resolved.text_record && resolved.text_record['version'] == Specjour::VERSION
            resolved_ip = ip_from_hostname(resolved.target)
            uri = URI::Generic.build :scheme => reply.service_name, :host => resolved_ip, :port => resolved.port
            fetch_manager(uri)
          else
            puts "Found #{resolved.target} but its version doesn't match v#{Specjour::VERSION}. Skipping..."
          end
          break unless resolved.flags.more_coming?
        end
      end
    rescue Timeout::Error
    end

    def resolve_reply_to_uri(reply)
      Timeout.timeout(1) do
        DNSSD.resolve!(reply.name, reply.type, reply.domain, flags=0, reply.interface) do |resolved|
          Specjour.logger.debug "Bonjour discovered #{resolved.target}"
          if resolved.text_record && resolved.text_record['version'] == Specjour::VERSION
            resolved_ip = ip_from_hostname(resolved.target)
            uri = URI::Generic.build :scheme => reply.service_name, :host => resolved_ip, :port => resolved.port
            uri
          else
            puts "Found #{resolved.target} but its version doesn't match v#{Specjour::VERSION}. Skipping..."
          end
          break unless resolved.flags.more_coming?
        end
      end
    rescue Timeout::Error
    end

    def rsync_daemon
      @rsync_daemon ||= RsyncDaemon.new(project_path, project_name, rsync_port)
    end

    def set_up_manager(manager)
      manager.project_name = project_name
      manager.dispatcher_uri = dispatcher_uri
      manager.test_paths = test_paths
      manager.worker_task = worker_task
      at_exit do
        begin
          manager.interrupted = Specjour.interrupted?
        rescue DRb::DRbConnError
        end
      end
    end

    def wait_on_managers
      all_mangers_finished = false
      while !all_mangers_finished
        all_mangers_finished = manager_threads.all? do |thread|
          puts 'not all managers finished'
          thread_finished = thread.join(0.5)
          if thread_finished
            puts "thread finished:#{thread}"
            thread.exit
            return true
          end
        end
        puts "finished checking status of manager threads (they are still working)"
        puts "finding more managers"
        find_more_managers unless all_mangers_finished
        puts "finished finding more managers"
      end

    end

    def worker_task
      options[:worker_task] || 'run_tests'
    end
  end
end
