module Specjour
  class Connection
    include Protocol
    extend Forwardable

    attr_reader :uri, :retries
    attr_writer :socket

    def_delegators :socket, :flush, :close, :closed?, :gets, :each

    def self.wrap(established_connection)
      Specjour.logger.debug "---self.wrap---"

      host, port = established_connection.peeraddr.values_at(3,1)
      connection = new URI::Generic.build(:host => host, :port => port)
      connection.socket = established_connection
      connection
    end

    def initialize(uri)
      @uri = uri
      @retries = 0
    end

    alias to_str to_s

    def connect
      timeout { connect_socket }
    end

    def retries
      Specjour.logger.debug "-************--#{uri} - retries: #{@retries}"
      return @retries
    end

    def disconnect
      Specjour.logger.debug "---disconnecting---"
      socket.close if socket && !socket.closed?
    end

    def socket
      @socket ||= connect
    end

    def next_test
      Specjour.logger.debug "---getting next test---"
      will_reconnect do
        send_message(:ready)
        load_object socket.gets(TERMINATOR)
      end
    end

    def print(arg)
      will_reconnect do
        socket.print dump_object(arg)
      end
    end

    def puts(arg='')
      will_reconnect do
        print(arg << "\n")
      end
    end

    def send_message(method_name, *args)
      will_reconnect do
        print([method_name, *args])
        flush
      end
    end

    protected

    def connect_socket
      Specjour.logger.debug "---connect_socket---"
      @socket = TCPSocket.open(uri.host, uri.port)
    rescue Errno::ECONNREFUSED => error
      retry
    end

    def reconnect
      Specjour.logger.debug "---Reconnecting---"
      socket.close unless socket.closed?
      connect
    end

    def timeout(&block)
      Timeout.timeout(2.0, &block)
    #rescue Timeout::Error
    end

    def will_reconnect(&block)
      block.call
    rescue SystemCallError, IOError => error
      unless Specjour.interrupted?
        @retries += 1
        reconnect
        if retries <= 5
          retry 
        else
          Specjour.logger.debug "Error Reconnecting: tried #{@retries} times: #{error.to_s}"
        end
      end
    end
  end
end
