# Class: AgentSkillsConfigurations::Registry
**Inherits:** Object
    

Loads agent configurations, resolves paths, and exposes query helpers.

The Registry is the internal implementation class that handles:

*   Loading and parsing the YAML configuration file
*   Resolving environment variables to absolute paths
*   Handling fallback paths for missing directories
*   Detecting which agents are installed on the system
*   Caching results for performance

This class is typically used through the public API methods in the
{AgentSkillsConfigurations} module, but can also be used directly for advanced
use cases.

## Path Resolution

The Registry uses a sophisticated path resolution system that respects
environment variables and provides fallback locations. The resolution process
works as follows:

1.  Check if the configured environment variable is set and non-empty
2.  If set, use that value as the base path
3.  If not set, use the configured fallback path (often relative to home)
4.  Expand relative paths using the user's home directory

Example resolution flow for XDG_CONFIG_HOME:

    # Configuration in YAML:
    base_paths:
      xdg_config:
        env_var: XDG_CONFIG_HOME
        fallback: ".config"

    # With environment variable set:
    ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
    # => resolves to "/custom/xdg"

    # Without environment variable:
    ENV["XDG_CONFIG_HOME"] = nil
    # => resolves to "/Users/username/.config"

    # Empty environment variable treated as unset:
    ENV["XDG_CONFIG_HOME"] = ""
    # => resolves to "/Users/username/.config"

## Global Skills Path Resolution

Global skills paths are resolved relative to the agent's base path and support
multiple fallbacks. The Registry checks each candidate path in order and
returns the first one that exists:

    # Configuration in YAML:
    agents:
      - name: moltbot
        base_path: home
        global_skills_path: ".moltbot/skills"
        global_skills_path_fallbacks:
          - ".clawdbot/skills"
          - ".moltbot/skills"

    # Resolution order:
    # 1. Check ~/.moltbot/skills
    # 2. Check ~/.clawdbot/skills
    # 3. Check ~/.moltbot/skills (fallback)
    # 4. Return first existing path, or primary path if none exist

## Installation Detection

The Registry determines whether an agent is installed by checking the paths
configured in the agent's `detect_paths` array. Each path spec can be one of
several types:

*   **String**: Check if the path exists relative to the user's home directory
*   *Hash with `cwd`*: Check if the path exists relative to the current
    working directory
*   *Hash with `base` and `path`*: Check if the path exists relative to a
    configured base path
*   *Hash with `absolute`*: Check if the absolute path exists

An agent is considered installed if **any** of its detect paths exists.

Examples of detect paths:

    agents:
      - name: cursor
        detect_paths:
          - ".cursor"  # Check ~/.cursor exists

      - name: antigravity
        detect_paths:
          - { cwd: ".agent" }  # Check .agent exists in current dir
          - { base: home, path: ".gemini/antigravity" }  # Check ~/.gemini/antigravity exists

      - name: codex
        detect_paths:
          - ""  # Always considered installed (empty string matches)
          - { absolute: "/etc/codex" }  # Check /etc/codex exists

## Caching

The Registry caches the results of {all} and {installed} to avoid repeatedly
parsing the YAML file and checking file system paths. The cache can be cleared
using {reset}.

Use {reset} when:

*   Environment variables that affect path resolution have changed
*   Agents have been installed or uninstalled
*   The YAML configuration file has been modified

**@see** [] Public API module that uses this class

**@see** [] Path to the configuration file

**@since** [] 0.1.0



# Instance Methods
## all() [](#method-i-all)
Return all configured agents.

Returns a frozen array of all {Agent} objects defined in the configuration.
The result is cached on first call for performance. Path resolution happens
once during caching and the results are reused on subsequent calls.

Use {reset} to clear the cache and force re-resolution when needed.

**@raise** [Psych::SyntaxError] when the YAML is invalid (only on first call)

**@return** [Array<Agent>] frozen array of all agents with resolved paths

**@see** [] Clear the cache

**@see** [] Get only installed agents

**@since** [] 0.1.0


**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
all = registry.all
all.map(&:name)
# => ["amp", "claude-code", "cursor", "codex", ...]
```
**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
first_call = registry.all
second_call = registry.all
first_call.equal?(second_call)  # => true (same object)
first_call.frozen?              # => true
```## find(name) [](#method-i-find)
Find an agent by name.

Looks up an agent configuration by its canonical name and returns an {Agent}
value object with resolved paths. This method performs path resolution each
time it's called, so it reflects the current environment variables and file
system state.

**@param** [String] the canonical agent name from agents.yml

**@raise** [Error] when the agent name is unknown

**@return** [Agent] the resolved agent configuration with absolute paths

**@since** [] 0.1.0


**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
agent = registry.find("cursor")
agent.name              # => "cursor"
agent.global_skills_dir # => "/Users/username/.cursor/skills"
```
**@example**
```ruby
registry.find("unknown-agent")
# => raises AgentSkillsConfigurations::Error: Unknown agent: unknown-agent
```## initialize() [](#method-i-initialize)
Create a registry from the YAML configuration.

Loads the agents.yml file and parses it into a data structure that can be
queried for agent information. The YAML is loaded safely with permitted
classes for security.

**@raise** [Psych::SyntaxError] when the YAML is invalid or malformed

**@return** [Registry] a new registry instance with loaded configuration

**@since** [] 0.1.0


**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
registry.find("cursor").name  # => "cursor"
```## installed() [](#method-i-installed)
Return agents detected as installed on this machine.

Filters the list of all agents to those that are detected as installed.
Installation detection uses the paths configured in each agent's
`detect_paths` configuration. An agent is considered installed if **any** of
its detect paths exists.

Detection strategies:

*   String: Check if path exists relative to user's home directory
*   Hash with `cwd`: Check relative to current working directory
*   Hash with `base` and `path`: Check relative to configured base path
*   Hash with `absolute`: Check absolute path directly

The result is cached on first call. Use {reset} to clear the cache.

**@raise** [Psych::SyntaxError] when the YAML is invalid (only on first call)

**@return** [Array<Agent>] frozen array of installed agents with resolved paths

**@see** [] Get all configured agents

**@see** [] Clear the cache

**@since** [] 0.1.0


**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
installed = registry.installed
installed.map(&:name)
# => ["cursor", "claude-code"]
```
**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
installed_names = registry.installed.map(&:name)
installed_names.include?("cursor")  # => true (if installed)
installed_names.include?("unknown") # => false
```## reset() [](#method-i-reset)
Clear cached agent lists.

Clears the internal caches for {all} and {installed} results. This forces path
resolution to be re-executed on the next call, which is useful when:

*   Environment variables affecting path resolution have changed
*   Agents have been installed or uninstalled
*   The YAML configuration file has been modified

**@return** [void] 

**@see** [] Get all agents

**@see** [] Get installed agents

**@since** [] 0.1.0


**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
ENV["XDG_CONFIG_HOME"] = "/new/path"
registry.reset
agent = registry.find("amp")
agent.global_skills_dir # => "/new/path/agents/skills"
```
**@example**
```ruby
registry = AgentSkillsConfigurations::Registry.new
# Install an agent...
registry.reset
registry.installed # => includes newly installed agent
```