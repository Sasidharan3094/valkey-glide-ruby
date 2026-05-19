# frozen_string_literal: true

module Helper
  module Client
    include Generic

    def init(valkey)
      valkey.select 14
      valkey.flushdb
      valkey.select 15
      valkey.flushdb
      valkey
    rescue Valkey::CannotConnectError
      puts <<-MSG
        Cannot connect to Valkey.

        Make sure Valkey is running on localhost, port #{PORT}.
        This testing suite connects to the database 15.
      MSG
      exit 1
    end

    def cluster_mode?
      false
    end

    private

    def _new_client(options = {})
      client = Valkey.new(options.merge(port: PORT, timeout: TIMEOUT))
      # Explicitly SELECT the database after connection to ensure it's set
      # regardless of whether the URI database path is honoured by the FFI layer
      client.select(options[:db]) if options[:db]
      client
    end
  end
end
