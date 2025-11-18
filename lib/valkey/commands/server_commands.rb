# frozen_string_literal: true

class Valkey
  module Commands
    # this module contains commands related to server management.
    #
    # @see https://valkey.io/commands/#server
    #
    module ServerCommands
      # Asynchronously rewrite the append-only file.
      #
      # @return [String] `OK`
      def bgrewriteaof
        send_command(RequestType::BG_REWRITE_AOF)
      end

      # Asynchronously save the dataset to disk.
      #
      # @return [String] `OK`
      def bgsave
        send_command(RequestType::BG_SAVE)
      end

      # Get or set server configuration parameters.
      #
      # @param [Symbol] action e.g. `:get`, `:set`, `:resetstat`
      # @return [String, Hash] string reply, or hash when retrieving more than one
      #   property with `CONFIG GET`
      def config(action, *args)
        send("config_#{action.to_s.downcase}", *args)
      end

      # Get server configuration parameters.
      #
      # Sends the CONFIG GET command with the given arguments.
      #
      # @param [Array<String>] args Configuration parameters to get
      # @return [Hash, String] Returns a Hash if multiple parameters are requested,
      #   otherwise returns a String with the value.
      #
      # @example Get all configuration parameters
      #   config_get('*')
      #
      # @example Get a specific parameter
      #   config_get('maxmemory')
      #
      # @note Returns a Hash with parameter names as keys and values as values when multiple params requested.
      def config_get(*args)
        send_command(RequestType::CONFIG_GET, args) do |reply|
          if reply.is_a?(Array)
            Hash[*reply]
          else
            reply
          end
        end
      end

      # Set server configuration parameters.
      #
      # Sends the CONFIG SET command with the given key-value pairs.
      #
      # @param [Array<String>] args Key-value pairs to set configuration
      # @return [String] Returns "OK" if successful
      #
      # @example Set maxmemory to 100mb
      #   config_set('maxmemory', '100mb')
      def config_set(*args)
        send_command(RequestType::CONFIG_SET, args)
      end

      # Reset the server's statistics.
      #
      # Sends the CONFIG RESETSTAT command.
      #
      # @return [String] Returns "OK" if successful
      #
      # @example
      #   config_resetstat
      def config_resetstat
        send_command(RequestType::CONFIG_RESET_STAT)
      end

      # Rewrite the server configuration file.
      #
      # Sends the CONFIG REWRITE command.
      #
      # @return [String] Returns "OK" if successful
      #
      # @example
      #   config_rewrite
      def config_rewrite
        send_command(RequestType::CONFIG_REWRITE)
      end

      # Return the number of keys in the selected database.
      #
      # @return [Integer]
      def dbsize
        send_command(RequestType::DB_SIZE)
      end

      # Remove all keys from all databases.
      #
      # @param [Hash] options
      #   - `:async => Boolean`: async flush (default: false)
      # @return [String] `OK`
      def flushall(options = nil)
        if options && options[:async]
          send_command(RequestType::FLUSH_ALL, ["async"])
        else
          send_command(RequestType::FLUSH_ALL)
        end
      end

      # Remove all keys from the current database.
      #
      # @param [Hash] options
      #   - `:async => Boolean`: async flush (default: false)
      # @return [String] `OK`
      def flushdb(options = nil)
        if options && options[:async]
          send_command(RequestType::FLUSH_DB, ["async"])
        else
          send_command(RequestType::FLUSH_DB)
        end
      end

      # Get information and statistics about the server.
      #
      # @param [String, Symbol] cmd e.g. "commandstats"
      # @return [Hash<String, String>]
      def info(cmd = nil)
        send_command(RequestType::INFO, [cmd].compact) do |reply|
          if reply.is_a?(String)
            reply = Utils::HashifyInfo.call(reply)

            if cmd && cmd.to_s == "commandstats"
              # Extract nested hashes for INFO COMMANDSTATS
              reply = Hash[reply.map do |k, v|
                v = v.split(",").map { |e| e.split("=") }
                [k[/^cmdstat_(.*)$/, 1], Hash[v]]
              end]
            end
          end

          reply
        end
      end

      # Get the UNIX time stamp of the last successful save to disk.
      #
      # @return [Integer]
      def lastsave
        send_command(RequestType::LAST_SAVE)
      end

      # Listen for all requests received by the server in real time.
      #
      # There is no way to interrupt this command.
      #
      # @yield a block to be called for every line of output
      # @yieldparam [String] line timestamp and command that was executed
      def monitor
        synchronize do |client|
          client = client.pubsub
          client.call_v([:monitor])
          loop do
            yield client.next_event
          end
        end
      end

      # Synchronously save the dataset to disk.
      #
      # @return [String]
      def save
        send_command(RequestType::SAVE)
      end

      # Synchronously save the dataset to disk and then shut down the server.
      def shutdown
        synchronize do |client|
          client.disable_reconnection do
            client.call_v([:shutdown])
          rescue ConnectionError
            # This means Redis has probably exited.
            nil
          end
        end
      end

      # Make the server a slave of another instance, or promote it as master.
      def slaveof(host, port)
        send_command(RequestType::SLAVE_OF, [host, port])
      end

      # Interact with the slowlog (get, len, reset)
      #
      # @param [String] subcommand e.g. `get`, `len`, `reset`
      # @param [Integer] length maximum number of entries to return
      # @return [Array<String>, Integer, String] depends on subcommand
      def slowlog(subcommand, length = nil)
        args = [:slowlog, subcommand]
        args << Integer(length) if length
        send_command(args)
      end

      # Internal command used for replication.
      def sync
        send_command(RequestType::SYNC)
      end

      # Return the server time.
      #
      # @example
      #   r.time # => [ 1333093196, 606806 ]
      #
      # @return [Array<Integer>] tuple of seconds since UNIX epoch and
      #   microseconds in the current second
      def time
        send_command(RequestType::TIME)
      end

      # RequestType::DEBUG not exist
      def debug(*args)
        send_command(RequestType::DEBUG, args)
      end
    end
  end
end
