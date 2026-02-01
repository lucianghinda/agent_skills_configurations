# frozen_string_literal: true

require "test_helper"

class TestRegistry < Minitest::Test
  def setup
    @original_env = ENV.to_h
    @registry = AgentSkillsConfigurations::Registry.new
  end

  def teardown
    ENV.clear
    ENV.update(@original_env)
    AgentSkillsConfigurations.reset!
  end

  def test_xdg_config_home_env_var_respected
    ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
    agent = @registry.find("amp")
    assert_includes agent.global_skills_dir, "custom/xdg"
  end

  def test_xdg_config_home_falls_back_to_config
    ENV["XDG_CONFIG_HOME"] = nil
    agent = @registry.find("amp")
    assert_includes agent.global_skills_dir, ".config"
  end

  def test_claude_config_dir_env_var_respected
    ENV["CLAUDE_CONFIG_DIR"] = "/custom/claude"
    agent = @registry.find("claude-code")
    assert_includes agent.global_skills_dir, "custom/claude"
  end

  def test_claude_config_dir_falls_back_to_home_claude
    ENV["CLAUDE_CONFIG_DIR"] = nil
    agent = @registry.find("claude-code")
    assert_includes agent.global_skills_dir, ".claude"
  end

  def test_codex_home_env_var_respected
    ENV["CODEX_HOME"] = "/custom/codex"
    agent = @registry.find("codex")
    assert_includes agent.global_skills_dir, "custom/codex"
  end

  def test_codex_home_falls_back_to_home_codex
    ENV["CODEX_HOME"] = nil
    agent = @registry.find("codex")
    assert_includes agent.global_skills_dir, ".codex"
  end

  def test_empty_env_var_treated_as_unset
    ENV["XDG_CONFIG_HOME"] = ""
    agent = @registry.find("amp")
    assert_includes agent.global_skills_dir, ".config"
  end

  def test_all_agents_have_required_fields
    names = @registry.all.map(&:name)
    assert names.include?("amp")
    assert names.include?("claude-code")
    assert names.include?("cursor")
  end

  def test_all_names_are_unique
    names = @registry.all.map(&:name)
    assert_equal names.size, names.uniq.size
  end

  def test_skills_dir_is_relative
    @registry.all.each do |agent|
      refute_match(%r{^/}, agent.skills_dir)
    end
  end

  def test_global_skills_dir_is_absolute
    @registry.all.each do |agent|
      assert_match(%r{^/}, agent.global_skills_dir)
    end
  end

  def test_cursor_agent_spot_check
    agent = @registry.find("cursor")
    assert_equal "cursor", agent.name
    assert_equal "Cursor", agent.display_name
    assert_equal ".cursor/skills", agent.skills_dir
    assert_match(%r{\.cursor/skills$}, agent.global_skills_dir)
  end

  def test_windsurf_agent_spot_check
    agent = @registry.find("windsurf")
    assert_equal "windsurf", agent.name
    assert_equal "Windsurf", agent.display_name
    assert_equal ".windsurf/skills", agent.skills_dir
    assert_match(%r{codeium/windsurf/skills$}, agent.global_skills_dir)
  end

  def test_amp_agent_spot_check
    agent = @registry.find("amp")
    assert_equal "amp", agent.name
    assert_equal "Amp", agent.display_name
    assert_equal ".agents/skills", agent.skills_dir
    assert_match(%r{agents/skills$}, agent.global_skills_dir)
  end

  def test_claude_code_agent_spot_check
    agent = @registry.find("claude-code")
    assert_equal "claude-code", agent.name
    assert_equal "Claude Code", agent.display_name
    assert_equal ".claude/skills", agent.skills_dir
    assert_match(/skills$/, agent.global_skills_dir)
  end

  def test_find_raises_for_unknown_name
    error = assert_raises(AgentSkillsConfigurations::Error) do
      @registry.find("unknown-agent")
    end
    assert_match(/Unknown agent: unknown-agent/, error.message)
  end

  def test_all_returns_frozen_array
    agents = @registry.all
    assert agents.frozen?
    assert_equal agents, @registry.all
  end

  def test_detected_returns_frozen_array
    detected = @registry.detected
    assert detected.frozen?
    assert_equal detected, @registry.detected
  end

  def test_detected_is_subset_of_all
    all = @registry.all
    detected = @registry.detected
    detected.each do |agent|
      assert_includes all, agent
    end
  end
end
