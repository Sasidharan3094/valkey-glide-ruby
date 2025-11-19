# frozen_string_literal: true

require "test_helper"

class TestFunctionCommands < Minitest::Test
  include Helper::Client

  def setup
    super
    # Ensure the function registry is empty before running tests
    r.function_flush rescue nil
  end

  def teardown
    # Clean up after tests
    r.function_flush rescue nil
    super
  end

  def sample_library_code
    <<~LUA
      #!lua name=mylib
      valkey.register_function('myfunc', function(keys, args)
        return args[1]
      end)
    LUA
  end

  def test_function_load
    result = r.function_load(sample_library_code)
    assert_equal "mylib", result
  end

  def test_function_load_replace
    r.function_load(sample_library_code)
    
    # Loading again without replace should raise an error
    assert_raises(Valkey::CommandError) do
      r.function_load(sample_library_code)
    end
    
    # Loading with replace should work
    result = r.function_load(sample_library_code, replace: true)
    assert_equal "mylib", result
  end

  def test_function_list
    r.function_load(sample_library_code)
    
    list = r.function_list
    assert_kind_of Array, list
    assert list.size > 0
    
    # Check that our library is in the list
    lib = list.find { |l| l.is_a?(Array) && l.include?("mylib") }
    assert lib
  end

  def test_function_list_with_library_name
    r.function_load(sample_library_code)
    
    list = r.function_list(library_name: "mylib")
    assert_kind_of Array, list
    assert list.size > 0
  end

  def test_function_list_with_code
    r.function_load(sample_library_code)
    
    list = r.function_list(with_code: true)
    assert_kind_of Array, list
    assert list.size > 0
  end

  def test_function_delete
    r.function_load(sample_library_code)
    
    result = r.function_delete("mylib")
    assert_equal "OK", result
    
    # Verify it's deleted
    list = r.function_list
    lib = list.find { |l| l.is_a?(Array) && l.include?("mylib") }
    assert_nil lib
  end

  def test_function_flush
    r.function_load(sample_library_code)
    
    result = r.function_flush
    assert_equal "OK", result
    
    # Verify all functions are flushed
    list = r.function_list
    assert_equal [], list
  end

  def test_function_flush_async
    r.function_load(sample_library_code)
    
    result = r.function_flush(async: true)
    assert_equal "OK", result
  end

  def test_function_flush_sync
    r.function_load(sample_library_code)
    
    result = r.function_flush(sync: true)
    assert_equal "OK", result
  end

  def test_function_dump_and_restore
    r.function_load(sample_library_code)
    
    # Dump the functions
    payload = r.function_dump
    assert_kind_of String, payload
    assert payload.bytesize > 0
    
    # Flush and restore
    r.function_flush
    result = r.function_restore(payload)
    assert_equal "OK", result
    
    # Verify the library is restored
    list = r.function_list
    lib = list.find { |l| l.is_a?(Array) && l.include?("mylib") }
    assert lib
  end

  def test_function_restore_with_policy
    r.function_load(sample_library_code)
    payload = r.function_dump
    
    # Test FLUSH policy
    result = r.function_restore(payload, policy: "FLUSH")
    assert_equal "OK", result
    
    # Test REPLACE policy
    result = r.function_restore(payload, policy: "REPLACE")
    assert_equal "OK", result
  end

  def test_fcall
    r.function_load(sample_library_code)
    
    result = r.fcall("myfunc", keys: [], args: ["hello"])
    assert_equal "hello", result
  end

  def test_fcall_with_keys
    code = <<~LUA
      #!lua name=keylib
      valkey.register_function('keyfunc', function(keys, args)
        return keys[1]
      end)
    LUA
    
    r.function_load(code)
    
    result = r.fcall("keyfunc", keys: ["mykey"], args: [])
    assert_equal "mykey", result
  end

  def test_fcall_ro
    code = <<~LUA
      #!lua name=rolib
      valkey.register_function{
        function_name='rofunc',
        callback=function(keys, args) return args[1] end,
        flags={'no-writes'}
      }
    LUA
    
    r.function_load(code)
    
    result = r.fcall_ro("rofunc", keys: [], args: ["readonly"])
    assert_equal "readonly", result
  end

  def test_function_stats
    stats = r.function_stats
    assert_kind_of Array, stats
  end

  def test_function_kill
    # There's no function running, so this should raise an error
    assert_raises(Valkey::CommandError) do
      r.function_kill
    end
  end

  def test_function_convenience_method
    # Test the convenience method
    result = r.function(:load, sample_library_code)
    assert_equal "mylib", result
    
    list = r.function(:list)
    assert_kind_of Array, list
    
    result = r.function(:delete, "mylib")
    assert_equal "OK", result
  end
end
