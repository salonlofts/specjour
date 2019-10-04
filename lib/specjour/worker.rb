module Specjour

  class Worker
    include Protocol
    include SocketHelper
    attr_accessor :printer_uri
    attr_reader :number

    def initialize(options = {})
      ARGV.replace []
      $stdout = StringIO.new if options[:quiet]
      @number = options[:number].to_i
      self.printer_uri = options[:printer_uri]
      set_env_variables
      Specjour.load_custom_hooks
    end

    def printer_uri=(val)
      @printer_uri = URI.parse(val)
    end

    def prepare
      Configuration.prepare.call
    end

    def run_tests
      begin 
        Specjour.benchmark("execute afterfork:") do
          Configuration.after_fork.call
        end
        run_times = Hash.new(0)
        Specjour.logger.debug "worker: staring test loop"
        last_test_finished = Time.now
        while test = connection.next_test
          Specjour.logger.debug "worker: successfully retrieved next test"
          print_status(test)
          Specjour.logger.debug "worker: running test-- time since last test--#{Time.now - last_test_finished}"
          time = Benchmark.realtime { run_test test }
          last_test_finished = Time.now
          Specjour.logger.debug "worker: finished running test"
          profile(test, time)
          run_times[test_type(test)] += time
          Specjour.logger.debug "worker: going to send done message test"
          connection.send_message(:done)
        end
        Specjour.logger.debug "worker: out of test loop received '#{test}' for test"
        Specjour.logger.debug "worker: sending run times"

        send_run_times(run_times)
        Specjour.logger.debug "worker: sent run times"
      rescue => e
        Specjour.logger.debug "!!!!!!worker: Error in worker Loop:#{e}!!!!!!"
        Specjour.logger.debug e.backtrace
      ensure
        Specjour.logger.debug "worker: hit ensure disconnection"
        connection.disconnect
        Specjour.logger.debug "worker: hit ensure disconnection :after disconnection"
      end
    end

    protected

    def connection
      @connection ||= printer_connection
    end

    def printer_connection
      Connection.new printer_uri
    end

    def print_status(test)
      status = "[#{ENV['TEST_ENV_NUMBER']}] Running #{test}"
      $stdout.puts status
      $PROGRAM_NAME = "specjour#{status}"
    end

    def print_time_for(test, time)
      puts "[#{ENV['TEST_ENV_NUMBER']}] Finished #{test} in #{time.round(2)}\n"
    end

    def profile(test, time)
      connection.send_message(:add_to_profiler, [test, time])
      print_time_for(test, time)
    end

    def run_test(test)
      if test_type(test) == :cucumber
        run_feature test
      else
        run_spec test
      end
    end

    def run_feature(feature)
      Cucumber::Runner.run(feature)
    end

    def run_spec(spec)
      RSpec::Runner.run(spec, connection)
    end

    def send_run_times(run_times)
      [:rspec, :cucumber].each do |type|
        connection.send_message(:"#{type}_summary=", {:duration => sprintf("%6f", run_times[type])}) if run_times[type] > 0
      end
    end

    def test_type(test)
      test =~ /\.feature(:\d+)?$/ ? :cucumber : :rspec
    end

    def set_env_variables
      ENV['RSPEC_COLOR'] ||= 'true'
      ENV['TEST_ENV_NUMBER'] ||= number.to_s
    end
  end
end
