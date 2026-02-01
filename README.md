# AgentSkillsConfigurations

[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D_3.2.0-ruby.svg)](https://www.ruby-lang.org/)

A unified interface for discovering and accessing skill configuration paths for various AI coding agents.

AgentSkillsConfigurations provides a consistent API for working with 49+ AI coding agents including Cursor, Claude Code, Codex, Windsurf, and many more. It handles platform-specific path resolution, environment variable support, and automatic detection of installed agents.

This gem was inspired by https://github.com/vercel-labs/skills the part that takes care of the generating the paths to the configuration for each CLI agent/LLM. 

If you find that any configuration is not correct please submit a PR with the fix and include there a link where to confirm that the new path is the correct one.

In case you are using an LLM point it to [doc/AgentSkillsConfigurations.md](doc/AgentSkillsConfigurations.md) which should behave like LLM.txt allowing any LLM to understand how to use this gem. 

## Features

- **Unified API**: Access 49+ AI coding agents through a single, consistent interface
- **Path Resolution**: Automatic resolution of project-level and global skill directories
- **Environment Variables**: Support for XDG_CONFIG_HOME, CLAUDE_CONFIG_DIR, CODEX_HOME, and more
- **Detection**: Automatically detect which agents are installed on your system
- **Fallbacks**: Intelligent fallback paths for global skills
- **Caching**: Performance-optimized with built-in caching

## Installation

Add this line to your application's Gemfile:

```ruby
gem "agent_skills_configurations"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install agent_skills_configurations
```

## Quick Start

```ruby
require "agent_skills_configurations"

# Find a specific agent
agent = AgentSkillsConfigurations.find("cursor")
agent.name              # => "cursor"
agent.display_name      # => "Cursor"
agent.skills_dir        # => ".cursor/skills"
agent.global_skills_dir # => "/Users/username/.cursor/skills"

# List all detected agents
AgentSkillsConfigurations.detected.map(&:name)
# => ["cursor", "claude-code", "windsurf", ...]

# List all configured agents (49+ supported)
AgentSkillsConfigurations.all.map(&:name)
# => ["amp", "claude-code", "cursor", "codex", "windsurf", ...]
```

## Usage

### Finding Agents

Get a specific agent configuration by name:

```ruby
agent = AgentSkillsConfigurations.find("claude-code")
agent.name              # => "claude-code"
agent.display_name      # => "Claude Code"
agent.skills_dir        # => ".claude/skills"
agent.global_skills_dir # => "/Users/username/.claude/skills"
```

Finding an unknown agent raises an error:

```ruby
AgentSkillsConfigurations.find("unknown-agent")
# => raises AgentSkillsConfigurations::Error: Unknown agent: unknown-agent
```

### Listing All Configured Agents

Get all 49+ configured agents:

```ruby
all_agents = AgentSkillsConfigurations.all
all_agents.map(&:name)
# => ["amp", "claude-code", "cursor", "codex", "windsurf", ...]

# Iterate through all agents
AgentSkillsConfigurations.all.each do |agent|
  puts "#{agent.display_name}: #{agent.skills_dir}"
end
```

### Detecting Installed Agents

Find which agents are detected on the current machine:

```ruby
detected = AgentSkillsConfigurations.detected
detected.map(&:name)
# => ["cursor", "claude-code"]

# Check if a specific agent is detected
installed_names = AgentSkillsConfigurations.detected.map(&:name)
installed_names.include?("cursor")  # => true
installed_names.include?("unknown") # => false
```

Detection works by checking configured paths:

- **String paths**: Check if path exists relative to user's home directory
- **Hash with `cwd`**: Check relative to current working directory
- **Hash with `base`**: Resolve using a configured base path
- **Hash with `absolute`**: Check absolute path directly

### Clearing Cache

Clear the cached agent lists when needed:

```ruby
# After changing environment variables
ENV["XDG_CONFIG_HOME"] = "/new/path"
AgentSkillsConfigurations.reset!

# After agents' paths are created or removed
AgentSkillsConfigurations.reset!
detected = AgentSkillsConfigurations.detected
```

### Environment Variables

Global skill paths are resolved using environment variables when available, with automatic fallbacks:

```ruby
# XDG_CONFIG_HOME for Amp, Goose, and other XDG-compliant agents
ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
agent = AgentSkillsConfigurations.find("amp")
agent.global_skills_dir  # => "/custom/xdg/agents/skills"

# CLAUDE_CONFIG_DIR for Claude Code and OpenCode
ENV["CLAUDE_CONFIG_DIR"] = "/custom/claude"
agent = AgentSkillsConfigurations.find("claude-code")
agent.global_skills_dir # => "/custom/claude/skills"

# CODEX_HOME for Codex
ENV["CODEX_HOME"] = "/custom/codex"
agent = AgentSkillsConfigurations.find("codex")
agent.global_skills_dir # => "/custom/codex/skills"
```

Without environment variables, paths fall back to default locations:

```ruby
ENV["XDG_CONFIG_HOME"] = nil
agent = AgentSkillsConfigurations.find("amp")
agent.global_skills_dir  # => "/Users/username/.config/agents/skills"
```

### Path Resolution with Fallbacks

Some agents support multiple fallback paths for global skills. The library checks each candidate path in order and returns the first one that exists:

```ruby
# Configuration in YAML:
#   - name: moltbot
#     global_skills_path: ".moltbot/skills"
#     global_skills_path_fallbacks:
#       - ".clawdbot/skills"
#       - ".moltbot/skills"

# Resolution order:
# 1. Check ~/.moltbot/skills
# 2. Check ~/.clawdbot/skills
# 3. Check ~/.moltbot/skills (fallback)
# 4. Return first existing path, or primary path if none exist
```

## Supported Agents

The gem includes configuration for 49+ AI coding agents:

- Aider, Amp, Antigravity, Avante, Bolt.new, Cline
- Claude Code, CodeBuddy, Codeium, Command Code, Copilot, Codex, Crush
- DeepSeek, Droid, Fabric
- GitHub Copilot, GPT-CLI, Gemini CLI, Goose
- Junie, Kaito, Kilo, Kimi CLI, Kiro CLI, Kode
- Moltbot, MCPJam, Mux
- Neovate, OpenClaude IDE, OpenCode, OpenHands, Pochi, Perplexity, Phind
- Qoder, Qwen Code, Roo Code
- SageMaker, Tabby, Trae CN, Trae
- v0 CLI, Windsurf, Zencoder
- And more!

If you find that any configuration is not correct please submit a PR with the fix and include there a link where to confirm that the new path is the correct one.

## Advanced Topics

### Understanding Skill Directories

AI coding agents typically support two types of skills:

1. **Project Skills** (`skills_dir`): These are specific to a single project and live alongside the project code. For example, a project might have a `.cursor/skills` directory containing skills tailored to that project.

2. **Global Skills** (`global_skills_dir`): These are shared across all projects and typically live in the user's home directory. For example, `~/.cursor/skills` contains reusable skills that work with any project.

When working with skills, you typically:
- Check the project's `skills_dir` for project-specific skills
- Fall back to `global_skills_dir` for general-purpose skills
- Combine both sources to give the agent full access to available skills

### Custom Agent Configurations

Agent configurations are defined in `lib/agent_skills_configurations/agents.yml`. To add a new agent, add an entry to the `agents` array:

```yaml
agents:
  - name: your-agent
    display_name: Your Agent
    skills_dir: ".your-agent/skills"
    base_path: home
    global_skills_path: ".your-agent/skills"
    detect_paths:
      - ".your-agent"
```

### Base Paths

Base paths are defined in the YAML configuration and support environment variables:

```yaml
base_paths:
  xdg_config:
    env_var: XDG_CONFIG_HOME
    fallback: ".config"
  home:
    env_var: ""
    fallback: ""
  claude_home:
    env_var: CLAUDE_CONFIG_DIR
    fallback: ".claude"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
# Install dependencies
bin/setup

# Run tests
rake test

# Start interactive console
bin/console
```

To install this gem onto your local machine, run:

```bash
bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lucianghinda/agent_skills_configurations. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/lucianghinda/agent_skills_configurations/blob/main/CODE_OF_CONDUCT.md).

### Running Tests

Make sure all tests pass before submitting a pull request:

```bash
rake test
```

## License

The gem is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/license/apache-2-0).

## Code of Conduct

Everyone interacting in the AgentSkillsConfigurations project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/lucianghinda/agent_skills_configurations/blob/main/CODE_OF_CONDUCT.md).
