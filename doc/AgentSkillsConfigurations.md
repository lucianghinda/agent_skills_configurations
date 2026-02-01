# Module: AgentSkillsConfigurations
    

AgentSkillsConfigurations provides a unified interface for discovering and
accessing skill configuration paths for various AI coding agents (Cursor,
Claude Code, Codex, etc.).

This library loads agent configurations from a YAML file and resolves
platform-specific paths for skill directories, taking into account environment
variables, user home directories, and fallback locations. It supports
detection of which agents are currently installed on the system and provides
convenient query methods for accessing agent information.

## Overview

Each AI coding agent has two types of skill directories:

1.  *Project-level skills* (skills_dir): A relative path within a project
    where project-specific skills are stored (e.g., `.cursor/skills`,
    `.claude/skills`)
2.  *Global skills* (global_skills_dir): An absolute path to the user's global
    skill repository shared across all projects (e.g., `~/.cursor/skills`)

The library abstracts away the differences between agents, providing a
consistent API for working with any supported agent type.

## Configuration

Agent configurations are defined in `agents.yml`, which contains:

*   Base path definitions with environment variable references and fallbacks
*   Agent entries with names, display names, skill paths, and detection rules

Example YAML structure:

    base_paths:
      home:
        env_var: ""
        fallback: ""
      xdg_config:
        env_var: XDG_CONFIG_HOME
        fallback: ".config"

    agents:
      - name: cursor
        display_name: Cursor
        skills_dir: ".cursor/skills"
        base_path: home
        global_skills_path: ".cursor/skills"
        detect_paths:
          - ".cursor"

## Finding Agents

To get a specific agent configuration by name:

    agent = AgentSkillsConfigurations.find("cursor")
    agent.name              # => "cursor"
    agent.display_name      # => "Cursor"
    agent.skills_dir        # => ".cursor/skills"
    agent.global_skills_dir # => "/Users/username/.cursor/skills"

Finding an unknown agent raises an error:

    AgentSkillsConfigurations.find("unknown-agent")
    # => raises AgentSkillsConfigurations::Error: Unknown agent: unknown-agent

## Listing All Agents

To get all configured agents:

    all_agents = AgentSkillsConfigurations.all
    all_agents.map(&:name)
    # => ["amp", "claude-code", "cursor", "codex", "windsurf", ...]

The result is cached for performance. Use {reset!} to clear the cache:

    AgentSkillsConfigurations.reset!

## Detecting Installed Agents

To find which agents are installed on the current machine:

    installed = AgentSkillsConfigurations.installed
    installed.map(&:name)
    # => ["cursor", "claude-code"]

Installation detection works by checking configured paths:

*   String paths: Checks if the path exists relative to the user's home
    directory
*   Hash paths with `cwd`: Checks relative to the current working directory
*   Hash paths with `base`: Resolves using the configured base path
*   Hash paths with `absolute`: Checks the absolute path directly

Examples from the configuration:

    detect_paths:
      - ".cursor"                    # Check ~/.cursor exists
      - { cwd: ".agent" }             # Check .agent exists in current dir
      - { base: home, path: ".codex" } # Check ~/.codex exists
      - { absolute: "/etc/codex" }    # Check /etc/codex exists

## Environment Variables

Global skill paths are resolved using environment variables when available,
with automatic fallbacks to default locations:

*   `XDG_CONFIG_HOME`: Used by Amp, Goose, and other XDG-compliant agents
*   `CLAUDE_CONFIG_DIR`: Used by Claude Code and OpenCode
*   `CODEX_HOME`: Used by Codex

Example with XDG_CONFIG_HOME:

    ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
    agent = AgentSkillsConfigurations.find("amp")
    agent.global_skills_dir  # => "/custom/xdg/agents/skills"

Without the environment variable, falls back to default:

    ENV["XDG_CONFIG_HOME"] = nil
    agent = AgentSkillsConfigurations.find("amp")
    agent.global_skills_dir  # => "/Users/username/.config/agents/skills"

## Path Resolution with Fallbacks

Some agents support multiple fallback paths for global skills. The first
existing path is used:

    agents:
      - name: moltbot
        global_skills_path: ".moltbot/skills"
        global_skills_path_fallbacks:
          - ".clawdbot/skills"
          - ".moltbot/skills"

The library checks each candidate path in order and returns the first one that
exists.

## Error Handling

The library raises {AgentSkillsConfigurations::Error} for configuration errors
(unknown agents) and {Psych::SyntaxError} for invalid YAML syntax.

**@author** [] Lucian Ghinda

**@since** [] 0.1.0


# Class Methods
## all() [](#method-c-all)
Return all configured agents.

Returns a frozen array of all {Agent} objects defined in the configuration.
The result is cached for performance. Use {reset!} to clear the cache when you
need fresh results (e.g., after changing environment variables).
**@raise** [Psych::SyntaxError] when the YAML configuration is invalid

**@return** [Array<Agent>] all agents defined in `agents.yml`

**@see** [] Clear cached agent lists

**@see** [] Get only installed agents

**@since** [] 0.1.0


**@example**
```ruby
all_agents = AgentSkillsConfigurations.all
all_agents.map(&:name)
# => ["amp", "claude-code", "cursor", "codex", "windsurf", ...]
```
**@example**
```ruby
AgentSkillsConfigurations.all.each do |agent|
  puts "#{agent.display_name}: #{agent.skills_dir}"
end
```
**@example**
```ruby
all = AgentSkillsConfigurations.all
cursor = all.find { |a| a.name == "cursor" }
cursor.global_skills_dir # => "/Users/username/.cursor/skills"
```## find(name ) [](#method-c-find)
Find a configured agent by name.

Returns an {Agent} value object containing the agent's name, display name, and
resolved skill directory paths. This is the primary method for accessing agent
configuration.
**@param** [String] agent name from `agents.yml`

**@raise** [Error] when the agent name is unknown

**@raise** [Psych::SyntaxError] when the YAML configuration is invalid

**@return** [Agent] resolved agent configuration

**@since** [] 0.1.0


**@example**
```ruby
agent = AgentSkillsConfigurations.find("cursor")
agent.name              # => "cursor"
agent.display_name      # => "Cursor"
agent.skills_dir        # => ".cursor/skills"
agent.global_skills_dir # => "/Users/username/.cursor/skills"
```
**@example**
```ruby
ENV["CLAUDE_CONFIG_DIR"] = "/custom/claude"
agent = AgentSkillsConfigurations.find("claude-code")
agent.global_skills_dir # => "/custom/claude/skills"
```
**@example**
```ruby
AgentSkillsConfigurations.find("unknown-agent")
# => raises AgentSkillsConfigurations::Error: Unknown agent: unknown-agent
```## installed() [](#method-c-installed)
Return agents that appear to be installed on this machine.

Installation is detected by checking the paths configured in each agent's
`detect_paths` configuration. Different detection strategies are supported:

*   String paths: Check if the path exists relative to user's home directory
*   Hash with `cwd`: Check relative to current working directory
*   Hash with `base`: Resolve using a configured base path
*   Hash with `absolute`: Check an absolute path directly

The result is cached for performance. Use {reset!} to clear the cache.
**@raise** [Psych::SyntaxError] when the YAML configuration is invalid

**@return** [Array<Agent>] agents matching their detect paths

**@see** [] Get all configured agents regardless of installation status

**@see** [] Clear cached agent lists

**@since** [] 0.1.0


**@example**
```ruby
installed = AgentSkillsConfigurations.installed
installed.map(&:name)
# => ["cursor", "claude-code"]
```
**@example**
```ruby
installed_names = AgentSkillsConfigurations.installed.map(&:name)
installed_names.include?("cursor")  # => true
installed_names.include?("unknown") # => false
```
**@example**
```ruby
AgentSkillsConfigurations.installed.each do |agent|
  puts "#{agent.display_name} is installed"
end
```## reset!() [](#method-c-reset!)
Clear cached agent lists.

This method clears the internal caches for {all} and {installed} results. Use
this when you need fresh data, such as:

*   After changing environment variables that affect path resolution
*   After installing or uninstalling agents
*   After modifying the YAML configuration file
**@raise** [Psych::SyntaxError] when the YAML configuration is invalid

**@return** [void] 

**@see** [] Returns cached all agents

**@see** [] Returns cached installed agents

**@since** [] 0.1.0


**@example**
```ruby
ENV["XDG_CONFIG_HOME"] = "/new/path"
AgentSkillsConfigurations.reset!
agent = AgentSkillsConfigurations.find("amp")
agent.global_skills_dir # => "/new/path/agents/skills"
```
**@example**
```ruby
AgentSkillsConfigurations.reset!
installed = AgentSkillsConfigurations.installed
```

# Documentation

- [AgentSkillsConfigurations/Agent.md](AgentSkillsConfigurations/Agent.md)
- [AgentSkillsConfigurations/Error.md](AgentSkillsConfigurations/Error.md)
- [AgentSkillsConfigurations/Registry.md](AgentSkillsConfigurations/Registry.md)
