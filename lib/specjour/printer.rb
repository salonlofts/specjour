require 'pry'
module Specjour

  class Printer
    include Protocol
    include SocketHelper
    RANDOM_PORT = 0
    CONNECTION_DEBUG = false
    
    attr_reader :port, :clients
    attr_accessor :tests_to_run, :example_size, :examples_complete, :profiler, :closed_socket_at_report, :tests_per_worker_report

    def initialize(opts={})
      @host = "0.0.0.0"
      @server_socket = TCPServer.new(@host, RANDOM_PORT)
      @port = @server_socket.addr[1]
      @profiler = {}
      @clients = {}
      @tests_to_run = []
      @example_size = 0
      @closed_socket_at_report = {}
      @tests_per_worker_report = {}
      self.examples_complete = 0
    end

    def start
      fds = [@server_socket]
      catch(:stop) do
        while true
          reads = select(fds).first
          reads.each do |socket_being_read|
            if socket_being_read == @server_socket
              client_socket = @server_socket.accept
              fds << client_socket
              clients[client_socket] = Connection.wrap(client_socket)
            elsif socket_being_read.eof?
              Specjour.logger.debug "Socket Closed: #{clients[socket_being_read].uri} workers_remaining:#{clients.size} tests_remaining:#{example_size - examples_complete }"
              closed_socket_at_report[clients[socket_being_read].uri] = Time.now
              socket_being_read.close
              fds.delete(socket_being_read)
              clients.delete(socket_being_read)
              disconnecting
            else
              serve(clients[socket_being_read])
            end
          end
        end
      end
    ensure
      stopping
      fds.each {|c| c.close}
    end

    def exit_status
      reporters.all? {|r| r.exit_status == true}  && !missing_tests?
    end

    protected

    def serve(client)
      data = load_object(client.gets(TERMINATOR))
      if CONNECTION_DEBUG
        Specjour.logger.debug ' '
        Specjour.logger.debug "|--------start client serve #{client.uri}--->"
        Specjour.logger.debug '|  ' + data.to_s[0..2000]
      end




      case data
      when String
        $stdout.print data
        $stdout.flush
      when Array
        send data.first, *(data[1..-1].unshift(client))
      else
        Specjour.logger.debug "client sent something other than an array or string it sent #{data}"
      end
      if CONNECTION_DEBUG
        Specjour.logger.debug "|---End client serve #{client.uri}---|"
        Specjour.logger.debug ' '
        Specjour.logger.debug ' '
      end
    end

    def ready(client)
      data_to_print = tests_to_run.shift
      Specjour.logger.debug "sending:#{data_to_print}" if CONNECTION_DEBUG
      client.print data_to_print
      client.flush
    end

    def done(client)
      self.examples_complete += 1
      record_tests_per_worker(client)
    end

    def record_tests_per_worker(client)
      tests_per_worker_report[client.uri.host.to_s] = {} unless tests_per_worker_report[client.uri.host.to_s]
      tests_per_worker_report[client.uri.host.to_s][:all] = 0 unless tests_per_worker_report[client.uri.host.to_s][:all]
      tests_per_worker_report[client.uri.host.to_s][client.uri.port.to_s] = 0 unless tests_per_worker_report[client.uri.host.to_s][client.uri.port.to_s]
      tests_per_worker_report[client.uri.host.to_s][:all] += 1
      tests_per_worker_report[client.uri.host.to_s][client.uri.port.to_s] += 1
    end

    def tests=(client, tests)
      if tests_to_run.empty?
        self.tests_to_run = run_order(tests)
        self.example_size = tests_to_run.size
      end
    end

    def rspec_summary=(client, summary)
      rspec_report.add(summary)
    end

    def cucumber_summary=(client, summary)
      cucumber_report.add(summary)
    end

    def add_to_profiler(client, args)
      test, time = *args
      self.profiler[test] = time
    end

    def disconnecting
      if (clients.empty? && examples_complete > 0) || !missing_tests?
        throw(:stop)
      end
    end

    def run_order(tests)
      if File.exist?('.specjour/performance')
        ordered_tests = File.readlines('.specjour/performance').map {|l| l.chop.split(':', 2)[1]}
        (tests - ordered_tests) | (ordered_tests & tests)
      else
        tests
      end
    end

    def summarize_tests_per_worker_report
      p '---------Tests per worker report-----------'
      tests_per_worker_report.keys.each do |host_uri|
        puts "#{host_uri} - #{hostname_from_ip(host_uri)} => #{tests_per_worker_report[host_uri][:all]}"
        tests_per_worker_report[host_uri].keys.reject{|port| port == :all}.each do |port|
          puts "                ->:#{port} #{tests_per_worker_report[host_uri][port]}"
        end
      end

    end

    def summarize_sockets_closed_early
      return unless closed_socket_at_report.size > 0
      early_socket_close_threshold = 3
      p '---------Sockets Closed at-----------'
      sockets_sorted_by_close_time = closed_socket_at_report.each.sort_by{|uri,close_time| close_time }

      last_socket_close_time = sockets_sorted_by_close_time.last[1]
      sockets_sorted_by_close_time.select{|uri,close_time| close_time < last_socket_close_time - early_socket_close_threshold}.each do |uri,close_time|
        puts "#{uri}: #{close_time}"
      end
    end

    def rspec_report
      @rspec_report ||= RSpec::FinalReport.new
    end

    def cucumber_report
      @cucumber_report ||= Cucumber::FinalReport.new
    end

    def record_performance
      File.open('.specjour/performance', 'w') do |file|
        ordered_specs = profiler.to_a.sort_by {|a| -a[1].to_f}.map do |test, time|
          file.puts "%6f:%s" % [time, test]
        end
      end
    end

    def reporters
      [@rspec_report, @cucumber_report].compact
    end

    def stopping
      summarize_reports
      unless Specjour.interrupted?
        record_performance
        print_missing_tests if missing_tests?
      end
    end

    def summarize_reports
      reporters.each {|r| r.summarize}
      summarize_tests_per_worker_report
      summarize_sockets_closed_early
    end

    def missing_tests?
      tests_to_run.any? || examples_complete != example_size
    end

    def print_missing_tests
      puts "*" * 60
      puts "Any tests to run?: #{tests_to_run.any?}"
      puts "examples_complete:#{examples_complete} example_size:#{example_size}"
      puts "Oops! The following tests were not run:"
      puts "*" * 60
      puts tests_to_run
      puts "*" * 60
    end

  end
end
