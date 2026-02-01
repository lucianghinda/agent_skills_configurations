# frozen_string_literal: true

module AgentSkillsConfigurations
  # Value object describing a configured agent and its skill locations.
  #
  # An Agent represents a single AI coding agent configuration with information about
  # where to find project-level skills and global skills for that agent. This is a
  # read-only data structure returned by {AgentSkillsConfigurations.find} and other
  # query methods.
  #
  # == Agent Attributes
  #
  # Each agent has four key attributes:
  #
  # * +name+ - The canonical identifier used in code (e.g., "cursor", "claude-code")
  # * +display_name+ - A human-friendly name for UI/display purposes (e.g., "Cursor", "Claude Code")
  # * +skills_dir+ - A relative path for project-specific skills (e.g., ".cursor/skills")
  # * +global_skills_dir+ - An absolute path to the user's global skill repository
  #
  # == Understanding Skill Directories
  #
  # AI coding agents typically support two types of skills:
  #
  # 1. *Project Skills* ({skills_dir}): These are specific to a single project and
  #    live alongside the project code. For example, a project might have a
  #    <tt>.cursor/skills</tt> directory containing skills tailored to that project.
  #
  # 2. *Global Skills* ({global_skills_dir}): These are shared across all projects
  #    and typically live in the user's home directory. For example,
  #    <tt>~/.cursor/skills</tt> contains reusable skills that work with any project.
  #
  # When working with skills, you typically:
  #
  # * Check the project's +skills_dir+ for project-specific skills
  # * Fall back to +global_skills_dir+ for general-purpose skills
  # * Combine both sources to give the agent full access to available skills
  #
  # == Accessing Agent Information
  #
  # Since Agent is a Data object, all attributes are accessible via reader methods:
  #
  #   agent = AgentSkillsConfigurations.find("cursor")
  #   agent.name              # => "cursor"
  #   agent.display_name      # => "Cursor"
  #   agent.skills_dir        # => ".cursor/skills"
  #   agent.global_skills_dir # => "/Users/username/.cursor/skills"
  #
  # You can also convert to a Hash:
  #
  #   agent.to_h
  #   # => { name: "cursor",
  #   #      display_name: "Cursor",
  #   #      skills_dir: ".cursor/skills",
  #   #      global_skills_dir: "/Users/username/.cursor/skills" }
  #
  # @attr_reader [String] name Canonical agent name from `agents.yml`. This is the
  #   identifier used when finding agents via {AgentSkillsConfigurations.find}.
  #
  # @attr_reader [String] display_name Human-friendly label for UI/display purposes.
  #   This is the name shown to users, e.g., in menus or configuration interfaces.
  #
  # @attr_reader [String] skills_dir Relative directory where project-specific
  #   skills live. This path is relative to the project root and should not start
  #   with a slash (e.g., ".cursor/skills", not "/.cursor/skills").
  #
  # @attr_reader [String] global_skills_dir Absolute resolved path to global skills.
  #   This path is resolved from the YAML configuration, taking into account
  #   environment variables and fallbacks. It always begins with a slash.
  #
  # @see AgentSkillsConfigurations.find Find an agent by name
  # @see AgentSkillsConfigurations.all Get all agents
  # @see AgentSkillsConfigurations.detected Get detected agents
  Agent = Data.define(:name, :display_name, :skills_dir, :global_skills_dir)
end
