# frozen_string_literal: true

class Valkey
  module Commands
    # This module contains commands related to connection management.
    #
    # @see https://valkey.io/commands/#connection
    #
    module ConnectionCommands
      # Authenticate to the server.
      #
      # @param [Array<String>] args includes both username and password
      #   or only password
      # @return [String] `OK`
      def auth(*args)
        send_command(RequestType::AUTH, args)
      end

      # Ping the server.
      #
      # @param [optional, String] message
      # @return [String] `PONG`
      def ping(message = nil)
        send_command(RequestType::PING, [message].compact)
      end

      # Echo the given string.
      #
      # @param [String] value
      # @return [String]
      def echo(value)
        send_command(RequestType::ECHO, [value])
      end

      # Change the selected database for the current connection.
      #
      # @param [Integer] db zero-based index of the DB to use (0 to 15)
      # @return [String] `OK`
      def select(db)
        send_command(RequestType::SELECT, [db])
      end

      # Close the connection.
      #
      # @return [String] `OK`
      def quit
        send_command(RequestType::QUIT)
      end

      # Switch to a different protocol version and handshake with the server.
      #
      # @param [Integer] protover Protocol version (2 or 3)
      # @param [Hash] options Optional parameters like AUTH, SETNAME
      # @return [Hash] Server information and capabilities
      def hello(protover = 3, **options)
        args = [protover]
        
        if options[:auth]
          args << "AUTH"
          args.concat(Array(options[:auth]))
        end
        
        if options[:setname]
          args << "SETNAME" << options[:setname]
        end

        send_command(RequestType::HELLO, args)
      end

      # Reset the connection state.
      #
      # @return [String] `RESET`
      def reset
        send_command(RequestType::RESET)
      end

      # Get the current client's ID.
      #
      # @return [Integer] Unique client ID
      def client_id
        send_command(RequestType::CLIENT_ID)
      end

      # Get the current client's name.
      #
      # @return [String, nil] Client name or nil if not set
      def client_get_name
        send_command(RequestType::CLIENT_GET_NAME)
      end

      # Set the current client's name.
      #
      # @param [String] name New name for the client connection
      # @return [String] `OK`
      def client_set_name(name)
        send_command(RequestType::CLIENT_SET_NAME, [name])
      end

      # Get a list of client connections.
      #
      # @param [String] type Optional filter by client type (normal, master, slave, pubsub)
      # @param [Array<String>] ids Optional filter by client IDs
      # @return [String] List of clients as a formatted string
      def client_list(type: nil, ids: nil)
        args = []
        
        if type
          args << "TYPE" << type
        end
        
        if ids
          args << "ID"
          args.concat(Array(ids))
        end

        send_command(RequestType::CLIENT_LIST, args)
      end

      # Get information about the current client connection.
      #
      # @return [String] Client connection information
      def client_info
        send_command(RequestType::CLIENT_INFO)
      end

      # Kill client connections.
      #
      # @param [String] addr Client address (ip:port)
      # @param [Hash] options Optional filters (id, type, user, addr, laddr, skipme)
      # @return [Integer] Number of clients killed
      def client_kill(addr = nil, **options)
        if addr && options.empty?
          # Simple form: CLIENT KILL ip:port
          send_command(RequestType::CLIENT_KILL_SIMPLE, [addr])
        else
          # Extended form with filters
          args = []
          
          if addr
            args << "ADDR" << addr
          end
          
          options.each do |key, value|
            case key
            when :id
              args << "ID" << value.to_s
            when :type
              args << "TYPE" << value.to_s
            when :user
              args << "USER" << value.to_s
            when :addr
              args << "ADDR" << value.to_s
            when :laddr
              args << "LADDR" << value.to_s
            when :skipme
              args << "SKIPME" << (value ? "yes" : "no")
            end
          end

          send_command(RequestType::CLIENT_KILL, args)
        end
      end

      # Pause client processing.
      #
      # @param [Integer] timeout Pause duration in milliseconds
      # @param [String] mode Optional mode (WRITE, ALL)
      # @return [String] `OK`
      def client_pause(timeout, mode = nil)
        args = [timeout]
        args << mode if mode
        send_command(RequestType::CLIENT_PAUSE, args)
      end

      # Unpause client processing.
      #
      # @return [String] `OK`
      def client_unpause
        send_command(RequestType::CLIENT_UNPAUSE)
      end

      # Configure client reply mode.
      #
      # @param [String] mode Reply mode (ON, OFF, SKIP)
      # @return [String] `OK`
      def client_reply(mode)
        send_command(RequestType::CLIENT_REPLY, [mode])
      end

      # Unblock a client blocked in a blocking operation.
      #
      # @param [Integer] client_id ID of the client to unblock
      # @param [String] unblock_type Optional unblock type (TIMEOUT, ERROR)
      # @return [Integer] 1 if client was unblocked, 0 otherwise
      def client_unblock(client_id, unblock_type = nil)
        args = [client_id]
        args << unblock_type if unblock_type
        send_command(RequestType::CLIENT_UNBLOCK, args)
      end

      # Set client connection information.
      #
      # @param [String] attr Attribute to set (lib-name, lib-ver)
      # @param [String] value Value to set for the attribute
      # @return [String] `OK`
      def client_set_info(attr, value)
        send_command(RequestType::CLIENT_SET_INFO, [attr, value])
      end

      # Enable/disable client caching.
      #
      # @param [String] mode Caching mode (YES, NO)
      # @return [String] `OK`
      def client_caching(mode)
        send_command(RequestType::CLIENT_CACHING, [mode])
      end

      # Configure client tracking.
      #
      # @param [String] status Tracking status (ON, OFF)
      # @param [Hash] options Optional parameters
      # @return [String] `OK`
      def client_tracking(status, **options)
        args = [status]
        
        options.each do |key, value|
          case key
          when :redirect
            args << "REDIRECT" << value.to_s
          when :prefix
            args << "PREFIX"
            Array(value).each { |prefix| args << prefix }
          when :bcast
            args << "BCAST" if value
          when :optin
            args << "OPTIN" if value
          when :optout
            args << "OPTOUT" if value
          when :noloop
            args << "NOLOOP" if value
          end
        end

        send_command(RequestType::CLIENT_TRACKING, args)
      end

      # Get client tracking information.
      #
      # @return [Array] Tracking information
      def client_tracking_info
        send_command(RequestType::CLIENT_TRACKING_INFO)
      end

      # Get the client ID used for tracking redirection.
      #
      # @return [Integer] Client ID for tracking redirection
      def client_getredir
        send_command(RequestType::CLIENT_GET_REDIR)
      end

      # Enable/disable client no-evict mode.
      #
      # @param [String] mode Mode (ON, OFF)
      # @return [String] `OK`
      def client_no_evict(mode)
        send_command(RequestType::CLIENT_NO_EVICT, [mode.to_s.upcase])
      end

      # Enable/disable client no-touch mode.
      #
      # @param [String] mode Mode (ON, OFF)
      # @return [String] `OK`
      def client_no_touch(mode)
        send_command(RequestType::CLIENT_NO_TOUCH, [mode.to_s.upcase])
      end
    end
  end
end
