# frozen_string_literal: true

require_relative "../test_helper"

class TestJsonCommands < Minitest::Test
  include Helper::Client
  include Lint::JsonCommands
end
