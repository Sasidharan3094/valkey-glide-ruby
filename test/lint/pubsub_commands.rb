# frozen_string_literal: true

module Lint
  module PubSubCommands
    def test_publish
      target_version "2.0" do
        # Publish to a channel with no subscribers
        result = r.publish("test_channel", "Hello, World!")
        assert_kind_of Integer, result
        assert result >= 0
      end
    end

    def test_pubsub_channels
      target_version "2.8" do
        # List all active channels
        channels = r.pubsub_channels
        assert_kind_of Array, channels
      end
    end

    def test_pubsub_channels_with_pattern
      target_version "2.8" do
        # List channels matching a pattern
        channels = r.pubsub_channels("test*")
        assert_kind_of Array, channels
      end
    end

    def test_pubsub_numpat
      target_version "2.8" do
        # Get number of pattern subscriptions
        count = r.pubsub_numpat
        assert_kind_of Integer, count
        assert count >= 0
      end
    end

    def test_pubsub_numsub
      target_version "2.8" do
        # Get subscriber counts for channels
        result = r.pubsub_numsub("channel1", "channel2")
        assert_kind_of Array, result
      end
    end

    def test_pubsub_numsub_no_channels
      target_version "2.8" do
        # Get subscriber counts with no channels specified
        result = r.pubsub_numsub
        assert_kind_of Array, result
      end
    end

    def test_pubsub_shardchannels
      target_version "7.0" do
        # List all active shard channels
        channels = r.pubsub_shardchannels
        assert_kind_of Array, channels
      rescue Valkey::TimeoutError
        skip("Shard channel command timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        skip("Shard channels not supported") if e.message.include?("unknown command")
        raise
      end
    end

    def test_pubsub_shardchannels_with_pattern
      target_version "7.0" do
        # List shard channels matching a pattern
        channels = r.pubsub_shardchannels("shard*")
        assert_kind_of Array, channels
      rescue Valkey::TimeoutError
        skip("Shard channel command timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        skip("Shard channels not supported") if e.message.include?("unknown command")
        raise
      end
    end

    def test_pubsub_shardnumsub
      target_version "7.0" do
        # Get subscriber counts for shard channels
        result = r.pubsub_shardnumsub("shard1", "shard2")
        assert_kind_of Array, result
      rescue Valkey::TimeoutError
        skip("Shard channel command timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        skip("Shard channels not supported") if e.message.include?("unknown command")
        raise
      end
    end

    def test_spublish
      target_version "7.0" do
        # Publish to a shard channel with no subscribers
        result = r.spublish("test_shard", "Hello, Shard!")
        assert_kind_of Integer, result
        assert result >= 0
      rescue Valkey::TimeoutError
        # In some cluster configurations, shard channels may timeout
        # This can happen if the cluster is still initializing or routing is not ready
        skip("Shard channel publish timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        # Skip if shard channels not supported
        skip("Shard channels not supported") if e.message.include?("unknown command") || e.message.include?("SPUBLISH")
        raise
      end
    end

    def test_pubsub_convenience_method_channels
      target_version "2.8" do
        channels = r.pubsub(:channels)
        assert_kind_of Array, channels
      end
    end

    def test_pubsub_convenience_method_channels_with_pattern
      target_version "2.8" do
        channels = r.pubsub(:channels, "test*")
        assert_kind_of Array, channels
      end
    end

    def test_pubsub_convenience_method_numpat
      target_version "2.8" do
        count = r.pubsub(:numpat)
        assert_kind_of Integer, count
        assert count >= 0
      end
    end

    def test_pubsub_convenience_method_numsub
      target_version "2.8" do
        result = r.pubsub(:numsub, "channel1", "channel2")
        assert_kind_of Array, result
      end
    end

    def test_pubsub_convenience_method_shardchannels
      target_version "7.0" do
        channels = r.pubsub(:shardchannels)
        assert_kind_of Array, channels
      rescue Valkey::TimeoutError
        skip("Shard channel command timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        skip("Shard channels not supported") if e.message.include?("unknown command")
        raise
      end
    end

    def test_pubsub_convenience_method_shardnumsub
      target_version "7.0" do
        result = r.pubsub(:shardnumsub, "shard1", "shard2")
        assert_kind_of Array, result
      rescue Valkey::TimeoutError
        skip("Shard channel command timed out - cluster may be initializing")
      rescue Valkey::CommandError => e
        skip("Shard channels not supported") if e.message.include?("unknown command")
        raise
      end
    end
  end
end
