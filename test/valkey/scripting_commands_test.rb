# frozen_string_literal: true

require "test_helper"

class TestScriptingCommands < Minitest::Test
  include Helper::Client
  include Lint::ScriptingCommands

  def setup
    super
    r.script_flush
  end
end
