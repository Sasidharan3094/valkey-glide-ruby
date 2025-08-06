# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('libglide_ffi') do |ext|
  ext.lib_dir = 'dist/'
  ext.ext_dir = 'ext/valkey-glide/ffi'
  ext.tmp_dir = 'tmp/valkey-glide-ffi'
end

task :compile_libglide_ffi do
  puts "Building Rust library..."
  sh "cd ext/valkey-glide/ffi && cargo build --release"

  # Copy .so (or .dylib/.dll) to lib/my_ruby_gem/native/
  lib_ext =
    case RUBY_PLATFORM
    when /darwin/ then 'dylib'
    when /linux/ then 'so'
    when /mingw|mswin/ then 'dll'
    else raise "Unknown platform #{RUBY_PLATFORM}"
    end

  cp Dir["ext/valkey-glide/ffi/target/release/*.{#{lib_ext}}"].first,
     "dist/libglide_ffi.#{lib_ext}"
end

task build: :compile_libglide_ffi

namespace :test do
  groups = %i[valkey cluster]
  groups.each do |group|
    Rake::TestTask.new(group) do |t|
      t.libs << "test"
      t.libs << "lib"
      t.test_files = FileList["test/#{group}/**/*_test.rb"]
      t.options = '-v' if ENV['CI'] || ENV['VERBOSE']
    end
  end

  lost_tests = Dir["test/**/*_test.rb"] - groups.map { |g| Dir["test/#{g}/**/*_test.rb"] }.flatten
  abort "The following test files are in no group:\n#{lost_tests.join("\n")}" unless lost_tests.empty?
end

task test: ["test:valkey"]

task default: :test
