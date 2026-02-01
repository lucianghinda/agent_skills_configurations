# frozen_string_literal: true

require "test_helper"

class TestAgent < Minitest::Test
  def test_data_class_to_h
    agent = AgentSkillsConfigurations::Agent.new(
      name: "test",
      display_name: "Test",
      skills_dir: ".test/skills",
      global_skills_dir: "/home/test/.test/skills"
    )
    expected = {
      name: "test",
      display_name: "Test",
      skills_dir: ".test/skills",
      global_skills_dir: "/home/test/.test/skills"
    }
    assert_equal expected, agent.to_h
  end

  def test_data_class_readers
    agent = AgentSkillsConfigurations::Agent.new(
      name: "test",
      display_name: "Test",
      skills_dir: ".test/skills",
      global_skills_dir: "/home/test/.test/skills"
    )
    assert_equal "test", agent.name
    assert_equal "Test", agent.display_name
    assert_equal ".test/skills", agent.skills_dir
    assert_equal "/home/test/.test/skills", agent.global_skills_dir
  end
end
