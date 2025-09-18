# frozen_string_literal: true

module Lint
  module ConnectionCommands
    def test_ping_without_message
      assert_equal "PONG", r.ping
    end

    def test_ping_with_message
      message = "Hello World"
      assert_equal message, r.ping(message)
    end

    def test_echo
      message = "Hello Valkey"
      assert_equal message, r.echo(message)
    end

    def test_auth_no_password
      # Test auth when no password is set - should raise error
      assert_raises(Valkey::CommandError) do
        r.auth("some_password")
      end
    end

    def test_select_database
      assert_equal "OK", r.select(0)
      
      # In cluster mode, only database 0 is supported
      if cluster_mode?
        assert_raises(Valkey::CommandError) do
          r.select(1)
        end
      else
        assert_equal "OK", r.select(1)
        assert_equal "OK", r.select(0) # Switch back to default
      end
    end

    def test_client_id
      id = r.client_id
      assert_kind_of Integer, id
      assert_operator id, :>, 0
    end

    def test_client_set_get_name
      name = "lint_test_client"
      
      # Set client name
      assert_equal "OK", r.client_set_name(name)
      
      # Get client name
      assert_equal name, r.client_get_name
      
      # Clear client name
      assert_equal "OK", r.client_set_name("")
      assert_nil r.client_get_name
    end

    def test_client_list
      list = r.client_list
      assert_kind_of String, list
      assert list.include?("id="), "Client list should contain client ID"
    end

    def test_client_info
      info = r.client_info
      assert_kind_of String, info
      assert info.include?("id="), "Client info should contain client ID"
    end

    def test_client_pause_unpause
      assert_equal "OK", r.client_pause(50) # 50ms pause
      sleep(0.1) # Wait for pause to take effect
      assert_equal "OK", r.client_unpause
    end

    def test_client_reply
      assert_equal "OK", r.client_reply("ON")
    end

    def test_client_set_info
      assert_equal "OK", r.client_set_info("lib-name", "valkey-ruby")
      
      assert_raises(Valkey::CommandError) do
        r.client_set_info("invalid-attr", "value")
      end
    end

    def test_client_unblock
      client_id = r.client_id
      result = r.client_unblock(client_id)
      assert [0, 1].include?(result), "Unblock should return 0 or 1"
    end

    def test_client_no_evict
      assert_equal "OK", r.client_no_evict("ON")
      assert_equal "OK", r.client_no_evict("OFF")
      
      assert_raises(Valkey::CommandError) do
        r.client_no_evict("INVALID")
      end
    end

    def test_client_no_touch
      assert_equal "OK", r.client_no_touch("ON")
      assert_equal "OK", r.client_no_touch("OFF")
      
      assert_raises(Valkey::CommandError) do
        r.client_no_touch("INVALID")
      end
    end

    def test_client_getredir
      redir = r.client_getredir
      assert_kind_of Integer, redir
    end

    def test_hello_default
      result = r.hello
      assert_kind_of Hash, result
      assert result.key?("server"), "HELLO response should contain server info"
    end

    def test_hello_with_version
      result = r.hello(3)
      assert_kind_of Hash, result
      assert_equal 3, result["proto"]
    end

    def test_hello_with_setname
      client_name = "hello_lint_test"
      result = r.hello(3, setname: client_name)
      assert_kind_of Hash, result
      assert_equal client_name, r.client_get_name
    end

    def test_reset
      # Set some state
      r.client_set_name("before_reset")
      
      # In cluster mode, we can only use database 0
      unless cluster_mode?
        r.select(1)
      end
      
      # Reset
      result = r.reset
      assert_equal "RESET", result
      
      # State should be reset
      assert_nil r.client_get_name
    end

    def test_client_caching
      skip("CLIENT CACHING command not implemented in backend yet")
      
      assert_equal "OK", r.client_caching("YES")
      assert_equal "OK", r.client_caching("NO")
    end

    def test_client_tracking
      skip("CLIENT TRACKING command not implemented in backend yet")
      
      assert_equal "OK", r.client_tracking("ON")
      assert_equal "OK", r.client_tracking("OFF")
    end

    def test_client_tracking_info
      skip("CLIENT TRACKING command not implemented in backend yet")
      
      info = r.client_tracking_info
      assert_kind_of Array, info
    end

    def test_quit
      # Note: This test is tricky because QUIT closes the connection
      # We'll skip it in lint tests to avoid connection issues
      skip("QUIT command closes connection - tested separately")
    end
  end
end
