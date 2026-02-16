# frozen_string_literal: true

module Lint
  module HyperLogLog
    def test_pfadd
      assert_equal true, r.pfadd("foo", "s1")
      assert_equal true, r.pfadd("foo", "s2")
      assert_equal false, r.pfadd("foo", "s1")

      assert_equal 2, r.pfcount("foo")
    end

    def test_variadic_pfadd
      assert_equal true, r.pfadd("foo", %w[s1 s2])
      assert_equal true, r.pfadd("foo", %w[s1 s2 s3])

      assert_equal 3, r.pfcount("foo")
    end

    def test_pfcount
      assert_equal 0, r.pfcount("foo")

      assert_equal true, r.pfadd("foo", "s1")

      assert_equal 1, r.pfcount("foo")
    end

    def test_variadic_pfcount
      assert_equal 0, r.pfcount(["{1}foo", "{1}bar"])

      assert_equal true, r.pfadd("{1}foo", "s1")
      assert_equal true, r.pfadd("{1}bar", "s1")
      assert_equal true, r.pfadd("{1}bar", "s2")

      assert_equal 2, r.pfcount("{1}foo", "{1}bar")
    end

    def test_variadic_pfcount_expanded
      assert_equal 0, r.pfcount("{1}foo", "{1}bar")

      assert_equal true, r.pfadd("{1}foo", "s1")
      assert_equal true, r.pfadd("{1}bar", "s1")
      assert_equal true, r.pfadd("{1}bar", "s2")

      assert_equal 2, r.pfcount("{1}foo", "{1}bar")
    end

    def test_pfmerge
      r.pfadd 'foo', 's1'
      r.pfadd 'bar', 's2'

      assert_equal true, r.pfmerge('res', 'foo', 'bar')
      assert_equal 2, r.pfcount('res')
    end

    def test_variadic_pfmerge_expanded
      r.pfadd('{1}foo', %w[foo bar zap a])
      r.pfadd('{1}bar', %w[a b c foo])
      assert_equal true, valkey.pfmerge('{1}baz', '{1}foo', '{1}bar')
    end

    # pfdebug tests

    def test_pfdebug
      r.pfadd("hll", "a")

      result = r.pfdebug("GETREG", "hll")
      assert_kind_of Array, result
    rescue Valkey::CommandError => e
      skip("PFDEBUG not available: #{e.message}") if e.message.include?("PFDEBUG") || e.message.include?("unknown")
      raise
    end

    # pfselftest tests

    def test_pfselftest
      # PFSELFTEST is an internal stress test that may time out or not be available
      result = r.pfselftest
      assert_equal "OK", result
    rescue Valkey::TimeoutError
      skip("PFSELFTEST timed out (internal stress test can be slow)")
    rescue Valkey::CommandError => e
      if e.message.include?("PFSELFTEST") || e.message.include?("unknown")
        skip("PFSELFTEST not available: #{e.message}")
      end
      raise
    end
  end
end
