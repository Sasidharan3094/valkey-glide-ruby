#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify OpenTelemetry metrics from Valkey GLIDE Ruby gem.
#
# GLIDE currently collects these metrics:
#   - glide.timeout_errors:  requests that exceeded their configured timeout
#   - glide.total_retries:   operations retried due to transient issues
#   - glide.moved_errors:    cluster slot reallocation responses
#
# This script forces timeouts by running a Lua busy-loop (~1-2s) while the
# client has a 100ms request timeout, then waits for the Rust OTel exporter
# to flush metrics to a file.
#
# Prerequisites:
#   - Valkey server running on localhost:6379
#   - valkey gem 7.2.0 installed
#
# Usage:
#   ruby -Ilib examples/test_opentelemetry.rb

require "valkey"
require "json"
require "fileutils"

TRACES_FILE  = "/tmp/valkey_otel_traces.json"
METRICS_FILE = "/tmp/valkey_otel_metrics.json"
FLUSH_INTERVAL_MS = 1000
WAIT_SECONDS = 15  # must keep process alive for Rust OTel background thread to flush

# Lua script: busy-loop 200M iterations (~1-2s) — well past the 100ms timeout.
BUSY_LUA_SCRIPT = <<~LUA
  local i = 0
  while i < 200000000 do
    i = i + 1
  end
  return "done"
LUA

# Clean up old export files
[TRACES_FILE, METRICS_FILE].each { |f| FileUtils.rm_f(f) }

puts "=== Valkey GLIDE Ruby — OpenTelemetry Timeout Metrics Test ==="
puts

# ── 1. Initialize OpenTelemetry ──────────────────────────────────────────────
puts "1) Initializing OpenTelemetry with file exporters..."
Valkey::OpenTelemetry.init(
  traces: {
    endpoint: "file://#{TRACES_FILE}",
    sample_percentage: 100
  },
  metrics: {
    endpoint: "file://#{METRICS_FILE}"
  },
  flush_interval_ms: FLUSH_INTERVAL_MS
)
puts "   initialized? #{Valkey::OpenTelemetry.initialized?}"
puts

# ── 2. Create a normal client for setup/cleanup ─────────────────────────────
puts "2) Connecting normal client (5s timeout) for setup..."
normal_client = Valkey.new(host: "localhost", port: 6379, timeout: 5000)
puts "   PING => #{normal_client.ping}"
puts

# ── 3. Create a short-timeout client (100ms) to trigger timeouts ─────────────
puts "3) Connecting short-timeout client (100ms)..."
short_client = Valkey.new(host: "localhost", port: 6379, timeout: 100)
puts "   PING => #{short_client.ping}"
puts

# ── 4. Run some normal commands via the short client (should succeed) ────────
puts "4) Running normal commands on short-timeout client..."
short_client.set("otel:test", "hello")
puts "   SET otel:test => OK"
val = short_client.get("otel:test")
puts "   GET otel:test => #{val}"
puts

# ── 5. Force timeouts using EVAL via send_command (CustomCommand path) ───────
puts "5) Forcing timeouts with Lua busy-loop (200M iterations, 100ms timeout)..."
timeout_count = 0
attempts = 5

attempts.times do |i|
  begin
    # Use send_command with CUSTOM_COMMAND to go through the command() FFI path
    # which creates OTel spans. This matches how the Python client sends EVAL.
    short_client.send_command(
      Valkey::RequestType::CUSTOM_COMMAND,
      ["EVAL", BUSY_LUA_SCRIPT, "0"]
    )
    puts "   Attempt #{i + 1}: unexpectedly succeeded"
  rescue Valkey::TimeoutError => e
    timeout_count += 1
    puts "   Attempt #{i + 1}: TIMEOUT (expected) — #{e.message}"
  rescue Valkey::CommandError => e
    puts "   Attempt #{i + 1}: CommandError — #{e.message}"
  rescue => e
    puts "   Attempt #{i + 1}: #{e.class} — #{e.message}"
  end

  # Small pause between attempts
  sleep 0.5
end

puts
puts "   Triggered #{timeout_count}/#{attempts} timeouts"
puts

# ── 6. Kill any lingering Lua script ─────────────────────────────────────────
puts "6) Cleaning up — killing any lingering script on server..."
begin
  normal_client.script(:kill)
  puts "   SCRIPT KILL => OK"
rescue => e
  puts "   SCRIPT KILL skipped (#{e.message})"
end
puts

# ── 7. Grab statistics ───────────────────────────────────────────────────────
puts "7) Client statistics:"
stats = normal_client.statistics
stats.each { |k, v| puts "   #{k}: #{v}" }
puts

# ── 8. Keep process alive for metrics flush ──────────────────────────────────
# The Rust OTel exporter runs on a background thread. If the Ruby process exits
# immediately, the runtime is torn down before metrics can be flushed.
# We keep the process alive (like the Python test does) to allow flushing.
puts "8) Waiting #{WAIT_SECONDS}s for OTel metrics flush (keeping runtime alive)..."
WAIT_SECONDS.times do |i|
  sleep 1
  # Periodically ping to keep the connection alive
  begin
    normal_client.ping if (i % 3).zero?
  rescue => e
    # ignore
  end
  print "."
end
puts
puts

# ── 9. Close clients ─────────────────────────────────────────────────────────
short_client.close
normal_client.close
puts "9) Clients closed."
puts

# ── 10. Display exported traces ──────────────────────────────────────────────
puts "========== TRACES =========="
if File.exist?(TRACES_FILE) && File.size(TRACES_FILE).positive?
  spans = []
  File.readlines(TRACES_FILE).each do |line|
    span = JSON.parse(line) rescue next
    spans << span
  end

  span_counts = spans.group_by { |s| s["name"] }.transform_values(&:count)
  span_counts.sort.each { |name, count| puts "#{name}: #{count} span(s)" }
  puts "Total: #{spans.size}"
else
  puts "⚠ No trace file found."
end
puts

# ── 11. Display exported metrics ─────────────────────────────────────────────
puts "========== METRICS =========="
if File.exist?(METRICS_FILE) && File.size(METRICS_FILE).positive?
  File.readlines(METRICS_FILE).each do |line|
    begin
      record = JSON.parse(line)
      # Extract metric name and value like the Python output
      scope_metrics = record.dig("scope_metrics") || []
      scope_metrics.each do |sm|
        (sm["metrics"] || []).each do |m|
          name = m["name"]
          (m["data_points"] || []).each do |dp|
            puts "#{name} = #{dp['value']}"
          end
        end
      end
    rescue JSON::ParserError
      next
    end
  end
  puts
  puts "Raw file: #{METRICS_FILE}"
else
  puts "⚠ No metrics file found."
end

puts
puts "Done."
