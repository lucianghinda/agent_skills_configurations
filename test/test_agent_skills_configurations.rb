# frozen_string_literal: true

require "test_helper"

class TestAgentSkillsConfigurations < Minitest::Test
  def setup
    @original_env = ENV.to_h
  end

  def teardown
    ENV.clear
    ENV.update(@original_env)
    AgentSkillsConfigurations.reset!
  end

  def test_that_it_has_a_version_number
    refute_nil ::AgentSkillsConfigurations::VERSION
  end

  def test_find_returns_agent
    agent = AgentSkillsConfigurations.find("claude-code")
    assert_equal "claude-code", agent.name
    assert_equal "Claude Code", agent.display_name
  end

  def test_find_raises_for_unknown
    error = assert_raises(AgentSkillsConfigurations::Error) do
      AgentSkillsConfigurations.find("unknown-agent")
    end
    assert_match(/Unknown agent: unknown-agent/, error.message)
  end

  def test_all_returns_all_agents
    agents = AgentSkillsConfigurations.all
    assert_equal 49, agents.size
    assert(agents.all? { |a| a.is_a?(AgentSkillsConfigurations::Agent) })
  end

  def test_detected_returns_subset
    all = AgentSkillsConfigurations.all
    detected = AgentSkillsConfigurations.detected
    assert detected.size <= all.size
    detected.each do |agent|
      assert_includes all, agent
    end
  end
end
