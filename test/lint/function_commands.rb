# frozen_string_literal: true

module Lint
  module FunctionCommands
    def test_function_delete
      target_version "7.0"

      code = <<~LUA
        #!lua name=testlib
        redis.register_function('testfunc', function(keys, args) return 'test' end)
      LUA

      r.function_load(code)
      assert_equal "OK", r.function_delete("testlib")
    end

    def test_function_dump
      target_version "7.0"

      code = <<~LUA
        #!lua name=dumplib
        redis.register_function('dumpfunc', function(keys, args) return 'dump' end)
      LUA

      r.function_load(code)
      payload = r.function_dump
      assert_kind_of String, payload
    end

    def test_function_flush
      target_version "7.0"

      code = <<~LUA
        #!lua name=flushlib
        redis.register_function('flushfunc', function(keys, args) return 'flush' end)
      LUA

      r.function_load(code)
      assert_equal "OK", r.function_flush
    end

    def test_function_flush_async
      target_version "7.0"

      code = <<~LUA
        #!lua name=asynclib
        redis.register_function('asyncfunc', function(keys, args) return 'async' end)
      LUA

      r.function_load(code)
      assert_equal "OK", r.function_flush(async: true)
    end

    def test_function_flush_sync
      target_version "7.0"

      code = <<~LUA
        #!lua name=synclib
        redis.register_function('syncfunc', function(keys, args) return 'sync' end)
      LUA

      r.function_load(code)
      assert_equal "OK", r.function_flush(sync: true)
    end

    def test_function_kill
      target_version "7.0"

      # No function running, should raise error
      assert_raises Valkey::CommandError do
        r.function_kill
      end
    end

    def test_function_list
      target_version "7.0"

      code = <<~LUA
        #!lua name=listlib
        redis.register_function('listfunc', function(keys, args) return 'list' end)
      LUA

      r.function_load(code)
      list = r.function_list
      assert_kind_of Array, list
    end

    def test_function_list_with_library_name
      target_version "7.0"

      code = <<~LUA
        #!lua name=namelib
        redis.register_function('namefunc', function(keys, args) return 'name' end)
      LUA

      r.function_load(code)
      list = r.function_list(library_name: "namelib")
      assert_kind_of Array, list
    end

    def test_function_list_with_code
      target_version "7.0"

      code = <<~LUA
        #!lua name=codelib
        redis.register_function('codefunc', function(keys, args) return 'code' end)
      LUA

      r.function_load(code)
      list = r.function_list(with_code: true)
      assert_kind_of Array, list
    end

    def test_function_load
      target_version "7.0"

      code = <<~LUA
        #!lua name=loadlib
        redis.register_function('loadfunc', function(keys, args) return 'load' end)
      LUA

      result = r.function_load(code)
      assert_equal "loadlib", result
    end

    def test_function_load_replace
      target_version "7.0"

      code = <<~LUA
        #!lua name=replacelib
        redis.register_function('replacefunc', function(keys, args) return 'replace' end)
      LUA

      r.function_load(code)
      result = r.function_load(code, replace: true)
      assert_equal "replacelib", result
    end

    def test_function_restore
      target_version "7.0"

      code = <<~LUA
        #!lua name=restorelib
        redis.register_function('restorefunc', function(keys, args) return 'restore' end)
      LUA

      r.function_load(code)
      payload = r.function_dump
      r.function_flush

      assert_equal "OK", r.function_restore(payload)
    end

    def test_function_restore_with_policy
      target_version "7.0"

      code = <<~LUA
        #!lua name=policylib
        redis.register_function('policyfunc', function(keys, args) return 'policy' end)
      LUA

      r.function_load(code)
      payload = r.function_dump

      assert_equal "OK", r.function_restore(payload, policy: "FLUSH")
    end

    def test_function_stats
      target_version "7.0"

      stats = r.function_stats
      assert_kind_of Array, stats
    end

    def test_fcall
      target_version "7.0"

      code = <<~LUA
        #!lua name=fcallib
        redis.register_function('fcallfunc', function(keys, args) return args[1] end)
      LUA

      r.function_load(code)
      result = r.fcall("fcallfunc", keys: [], args: ["test"])
      assert_equal "test", result
    end

    def test_fcall_with_keys
      target_version "7.0"

      code = <<~LUA
        #!lua name=keyslib
        redis.register_function('keysfunc', function(keys, args) return keys[1] end)
      LUA

      r.function_load(code)
      result = r.fcall("keysfunc", keys: ["mykey"], args: [])
      assert_equal "mykey", result
    end

    def test_fcall_ro
      target_version "7.0"

      code = <<~LUA
        #!lua name=rolib
        redis.register_function{
          function_name='rofunc',
          callback=function(keys, args) return args[1] end,
          flags={'no-writes'}
        }
      LUA

      r.function_load(code)
      result = r.fcall_ro("rofunc", keys: [], args: ["readonly"])
      assert_equal "readonly", result
    end
  end
end
