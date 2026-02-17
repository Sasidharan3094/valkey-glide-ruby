#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal debug script to isolate the metrics export issue.
# Compares behavior with the working Python client.

require "valkey"
require "json"
require "fileutils"

TRACES_FILE  = "/tmp/valkey_otel_traces.json"
METRICS_FILE = "/tmp/valkey_otel_metrics.json"

[TRACES_FILE, METRICS_FILE].each { |f| FileUtils.rm_f(f) }

puts "[*] Initializing OpenTelemetry..."
Valkey::OpenTelemetry.init(
  traces: {
    endpoint: "file://#{TRACES_FILE}",
    sample_percentage: 100
  },
  metrics: {
    endpoint: "file://#{METRICS_FILE}"
  },
  flush_interval_ms: 1000
)

puts "[+] OpenTelemetry initialized"

# Normal client for pings / cleanup
normal = Valkey.new(host: "localhost", port: 6379, timeout: 5000)
puts "[+] Normal client connected"

# Short-timeout client
short = Valkey.new(host: "localhost", port: 6379, timeout: 100)
puts "[+] Short-timeout client connected (100ms)"

# Force timeouts
5.times do |i|
  begin
    short.send_command(
      Valkey::RequestType::CUSTOM_COMMAND,
      ["EVAL", "local i=0 while i<200000000 do i=i+1 end return 'done'", "0"]
    )
  rescue Valkey::TimeoutError => e
    puts "[timeout #{i + 1}] TimeoutError: #{e.message}"
  rescue => e
    puts "[error #{i + 1}] #{e.class}: #{e.message}"
  end
  sleep 2
end

puts "[+] Triggered timeouts"

# Kill lingering script
begin
  normal.send_command(Valkey::RequestType::CUSTOM_COMMAND, ["SCRIPT", "KILL"])
  puts "[+] SCRIPT KILL OK"
rescue => e
  puts "[!] SCRIPT KILL: #{e.message}"
end

# Keep process alive — this is critical for the Rust OTel background exporter
puts "[*] Waiting for metrics flush (keeping runtime active)..."
20.times do |i|
  sleep 1
  # Check if metrics file appeared
  if File.exist?(METRICS_FILE) && File.size(METRICS_FILE).positive?
    puts "[+] Metrics file appeared at second #{i + 1}"
    break
  end
  # Keep connection alive
  begin
    normal.ping
  rescue
    nil
  end
  print "."
end
puts

# Now read results
puts
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
  puts "⚠ No traces file."
end

puts
puts "========== METRICS =========="
if File.exist?(METRICS_FILE) && File.size(METRICS_FILE).positive?
  File.readlines(METRICS_FILE).each do |line|
    begin
      record = JSON.parse(line)
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
  puts "⚠ No metrics file found after 20s wait."
  puts
  puts "Debug info:"
  puts "  Traces file exists: #{File.exist?(TRACES_FILE)}"
  puts "  Traces file size:   #{File.exist?(TRACES_FILE) ? File.size(TRACES_FILE) : 'N/A'}"
  puts "  Metrics file exists: #{File.exist?(METRICS_FILE)}"
  puts "  /tmp files matching glide/valkey:"
  Dir.glob("/tmp/*valkey*").concat(Dir.glob("/tmp/*glide*")).each { |f| puts "    #{f} (#{File.size(f)} bytes)" }
end

short.close
normal.close
puts
puts "[+] Done."
