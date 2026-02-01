# frozen_string_literal: true

require "yaml"

module AgentSkillsConfigurations
  # Loads agent configurations, resolves paths, and exposes query helpers.
  #
  # The Registry is the internal implementation class that handles:
  #
  #   * Loading and parsing the YAML configuration file
  #   * Resolving environment variables to absolute paths
  #   * Handling fallback paths for missing directories
  #   * Detecting which agents have their paths present
  #   * Caching results for performance
  #
  # This class is typically used through the public API methods in the
  # {AgentSkillsConfigurations} module, but can also be used directly for
  # advanced use cases.
  #
  # == Path Resolution
  #
  # The Registry uses a sophisticated path resolution system that respects
  # environment variables and provides fallback locations. The resolution
  # process works as follows:
  #
  # 1. Check if the configured environment variable is set and non-empty
  # 2. If set, use that value as the base path
  # 3. If not set, use the configured fallback path (often relative to home)
  # 4. Expand relative paths using the user's home directory
  #
  # Example resolution flow for XDG_CONFIG_HOME:
  #
  #   # Configuration in YAML:
  #   base_paths:
  #     xdg_config:
  #       env_var: XDG_CONFIG_HOME
  #       fallback: ".config"
  #
  #   # With environment variable set:
  #   ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
  #   # => resolves to "/custom/xdg"
  #
  #   # Without environment variable:
  #   ENV["XDG_CONFIG_HOME"] = nil
  #   # => resolves to "/Users/username/.config"
  #
  #   # Empty environment variable treated as unset:
  #   ENV["XDG_CONFIG_HOME"] = ""
  #   # => resolves to "/Users/username/.config"
  #
  # == Global Skills Path Resolution
  #
  # Global skills paths are resolved relative to the agent's base path
  # and support multiple fallbacks. The Registry checks each candidate path
  # in order and returns the first one that exists:
  #
  #   # Configuration in YAML:
  #   agents:
  #     - name: moltbot
  #       base_path: home
  #       global_skills_path: ".moltbot/skills"
  #       global_skills_path_fallbacks:
  #         - ".clawdbot/skills"
  #         - ".moltbot/skills"
  #
  #   # Resolution order:
  #   # 1. Check ~/.moltbot/skills
  #   # 2. Check ~/.clawdbot/skills
  #   # 3. Check ~/.moltbot/skills (fallback)
  #   # 4. Return first existing path, or primary path if none exist
  #
  # == Agent Detection
  #
  # The Registry determines whether an agent's paths are present by checking the
  # paths configured in the agent's +detect_paths+ array. Each path spec
  # can be one of several types:
  #
  # * *String*: Check if the path exists relative to the user's home directory
  # * *Hash with +cwd+*: Check if the path exists relative to the current working directory
  # * *Hash with +base+ and +path+*: Check if the path exists relative to a configured base path
  # * *Hash with +absolute+*: Check if the absolute path exists
  #
  # An agent is considered detected if <b>any</b> of its detect paths exists.
  #
  # Examples of detect paths:
  #
  #   agents:
  #     - name: cursor
  #       detect_paths:
  #         - ".cursor"  # Check ~/.cursor exists
  #
  #     - name: antigravity
  #       detect_paths:
  #         - { cwd: ".agent" }  # Check .agent exists in current dir
  #         - { base: home, path: ".gemini/antigravity" }  # Check ~/.gemini/antigravity exists
  #
  #     - name: codex
  #       detect_paths:
  #         - ""  # Always detected (empty string matches)
  #         - { absolute: "/etc/codex" }  # Check /etc/codex exists
  #
  # == Caching
  #
  # The Registry caches the results of {all} and {detected} to avoid
  # repeatedly parsing the YAML file and checking file system paths.
  # The cache can be cleared using {reset}.
  #
  # Use {reset} when:
  #
  # * Environment variables that affect path resolution have changed
  # * Agent paths have been created or removed
  # * The YAML configuration file has been modified
  #
  # @see AgentSkillsConfigurations Public API module that uses this class
  # @see YAML_PATH Path to the configuration file
  class Registry
    # Absolute path to the configuration file.
    #
    # The configuration file contains agent definitions, base path configurations,
    # and detection rules. This path is resolved relative to the gem's lib directory.
    #
    # @return [String] absolute path to agents.yml
    YAML_PATH = File.expand_path("agents.yml", __dir__)

    # Create a registry from the YAML configuration.
    #
    # Loads the agents.yml file and parses it into a data structure that
    # can be queried for agent information. The YAML is loaded safely
    # with permitted classes for security.
    #
    # @return [Registry] a new registry instance with loaded configuration
    # @raise [Psych::SyntaxError] when the YAML is invalid or malformed
    #
    # @example Create a registry
    #   registry = AgentSkillsConfigurations::Registry.new
    #   registry.find("cursor").name  # => "cursor"
    def initialize
      @data = YAML.safe_load_file(YAML_PATH, permitted_classes: [Hash], aliases: true)
    end

    # Find an agent by name.
    #
    # Looks up an agent configuration by its canonical name and returns an
    # {Agent} value object with resolved paths. This method performs path
    # resolution each time it's called, so it reflects the current
    # environment variables and file system state.
    #
    # @param name [String] the canonical agent name from agents.yml
    # @return [Agent] the resolved agent configuration with absolute paths
    # @raise [Error] when the agent name is unknown
    #
    # @example Find a specific agent
    #   registry = AgentSkillsConfigurations::Registry.new
    #   agent = registry.find("cursor")
    #   agent.name              # => "cursor"
    #   agent.global_skills_dir # => "/Users/username/.cursor/skills"
    #
    # @example Error for unknown agent
    #   registry.find("unknown-agent")
    #   # => raises AgentSkillsConfigurations::Error: Unknown agent: unknown-agent
    def find(name)
      entry = @data["agents"].find { |a| a["name"] == name }
      raise Error, "Unknown agent: #{name}" unless entry

      build_agent(entry)
    end

    # Return all configured agents.
    #
    # Returns a frozen array of all {Agent} objects defined in the configuration.
    # The result is cached on first call for performance. Path resolution happens
    # once during caching and the results are reused on subsequent calls.
    #
    # Use {reset} to clear the cache and force re-resolution when needed.
    #
    # @return [Array<Agent>] frozen array of all agents with resolved paths
    # @raise [Psych::SyntaxError] when the YAML is invalid (only on first call)
    #
    # @example Get all agents
    #   registry = AgentSkillsConfigurations::Registry.new
    #   all = registry.all
    #   all.map(&:name)
    #   # => ["amp", "claude-code", "cursor", "codex", ...]
    #
    # @example Verify array is frozen and cached
    #   registry = AgentSkillsConfigurations::Registry.new
    #   first_call = registry.all
    #   second_call = registry.all
    #   first_call.equal?(second_call)  # => true (same object)
    #   first_call.frozen?              # => true
    #
    # @see #reset Clear the cache
    # @see #detected Get only detected agents
    def all
      @all ||= @data["agents"].map { |entry| build_agent(entry) }.freeze
    end

    # Return agents detected on this machine.
    #
    # Filters the list of all agents to those that have their detect paths present.
    # Detection uses the paths configured in each agent's
    # <tt>detect_paths</tt> configuration. An agent is considered detected
    # if <b>any</b> of its detect paths exists.
    #
    # Detection strategies:
    #
    # * String: Check if path exists relative to user's home directory
    # * Hash with +cwd+: Check relative to current working directory
    # * Hash with +base+ and +path+: Check relative to configured base path
    # * Hash with +absolute+: Check absolute path directly
    #
    # The result is cached on first call. Use {reset} to clear the cache.
    #
    # @return [Array<Agent>] frozen array of detected agents with resolved paths
    # @raise [Psych::SyntaxError] when the YAML is invalid (only on first call)
    #
    # @example Get detected agents
    #   registry = AgentSkillsConfigurations::Registry.new
    #   detected = registry.detected
    #   detected.map(&:name)
    #   # => ["cursor", "claude-code"]
    #
    # @example Check if specific agent is detected
    #   registry = AgentSkillsConfigurations::Registry.new
    #   detected_names = registry.detected.map(&:name)
    #   detected_names.include?("cursor")  # => true (if detected)
    #   detected_names.include?("unknown") # => false
    #
    # @see #all Get all configured agents
    # @see #reset Clear the cache
    def detected
      @detected ||= all.select { |agent| detected?(agent) }.freeze
    end

    # Clear cached agent lists.
    #
    # Clears the internal caches for {all} and {detected} results. This
    # forces path resolution to be re-executed on the next call, which is
    # useful when:
    #
    # * Environment variables affecting path resolution have changed
    # * Agent paths have been created or removed
    # * The YAML configuration file has been modified
    #
    # @return [void]
    #
    # @example Reset after changing environment variable
    #   registry = AgentSkillsConfigurations::Registry.new
    #   ENV["XDG_CONFIG_HOME"] = "/new/path"
    #   registry.reset
    #   agent = registry.find("amp")
    #   agent.global_skills_dir # => "/new/path/agents/skills"
    #
    # @example Reset for fresh detection
    #   registry = AgentSkillsConfigurations::Registry.new
    #   # Create agent paths...
    #   registry.reset
    #   registry.detected # => includes newly detected agent
    #
    # @see #all Get all agents
    # @see #detected Get detected agents
    def reset
      @all = nil
      @detected = nil
    end

    private

    # Build an agent value object from a YAML entry.
    #
    # Creates an {Agent} object by resolving the base path and global skills
    # path from the YAML configuration. The base path is resolved first,
    # then used as the context for resolving the global skills path (including
    # any fallbacks).
    #
    # @param entry [Hash] the agent entry from the YAML configuration
    # @return [Agent] a new Agent instance with resolved absolute paths
    #
    # @example Build an agent from YAML entry
    #   entry = {
    #     "name" => "cursor",
    #     "display_name" => "Cursor",
    #     "skills_dir" => ".cursor/skills",
    #     "base_path" => "home",
    #     "global_skills_path" => ".cursor/skills"
    #   }
    #   build_agent(entry)
    #   # => #<Agent name="cursor" display_name="Cursor" ...>
    def build_agent(entry)
      base = resolve_base_path(entry["base_path"])
      global_path = resolve_global_skills_path(entry, base)

      Agent.new(
        name: entry["name"],
        display_name: entry["display_name"],
        skills_dir: entry["skills_dir"],
        global_skills_dir: global_path
      )
    end

    # Resolve a base path key into an absolute path.
    #
    # Looks up a base path configuration by key and resolves it to an absolute
    # path using the following priority:
    #
    # 1. If env_var is "~" or "", return the home directory directly
    # 2. If env_var is set and non-empty, use that value as the path
    # 3. Otherwise, use the configured fallback path (relative to home)
    #
    # This method ensures that empty environment variables are treated the same
    # as unset variables, preventing unexpected behavior.
    #
    # @param key [String] the base path key from the YAML configuration
    # @return [String] an absolute path
    #
    # @example Resolve XDG_CONFIG_HOME with environment variable
    #   # YAML: base_paths.xdg_config.env_var = "XDG_CONFIG_HOME"
    #   # YAML: base_paths.xdg_config.fallback = ".config"
    #   ENV["XDG_CONFIG_HOME"] = "/custom/xdg"
    #   resolve_base_path("xdg_config")  # => "/custom/xdg"
    #
    # @example Resolve XDG_CONFIG_HOME without environment variable
    #   ENV["XDG_CONFIG_HOME"] = nil
    #   resolve_base_path("xdg_config")  # => "/Users/username/.config"
    #
    # @example Resolve with empty environment variable
    #   ENV["XDG_CONFIG_HOME"] = ""
    #   resolve_base_path("xdg_config")  # => "/Users/username/.config"
    def resolve_base_path(key)
      config = @data["base_paths"][key]
      env_var = config["env_var"]
      home = Dir.home || "/tmp"

      return home if ["~", ""].include?(env_var)
      return ENV.fetch(env_var, nil) if env_var_set?(env_var)

      resolve_fallback(config["fallback"], home)
    end

    # True when an environment variable is set and non-empty.
    #
    # Checks if an environment variable exists and contains a non-empty value.
    # This distinction is important because an empty string should be treated
    # the same as an unset variable for path resolution purposes.
    #
    # @param env_var [String, nil] the environment variable name
    # @return [Boolean] true if the variable is set and non-empty
    #
    # @example Set environment variable
    #   ENV["VAR"] = "value"
    #   env_var_set?("VAR")  # => true
    #
    # @example Unset environment variable
    #   ENV.delete("VAR")
    #   env_var_set?("VAR")  # => false
    #
    # @example Empty environment variable
    #   ENV["VAR"] = ""
    #   env_var_set?("VAR")  # => false
    #
    # @example Nil environment variable name
    #   env_var_set?(nil)  # => false
    def env_var_set?(env_var)
      env_var && !ENV[env_var].nil? && !ENV[env_var].empty?
    end

    # Resolve a fallback path relative to the user's home directory.
    #
    # Joins the fallback path with the home directory, unless the fallback is
    # "~" or an empty string, in which case the home directory is returned
    # directly.
    #
    # @param fallback [String] the fallback path from YAML configuration
    # @param home [String] the user's home directory
    # @return [String] an absolute path
    #
    # @example Normal fallback
    #   resolve_fallback(".config", "/Users/username")
    #   # => "/Users/username/.config"
    #
    # @example Tilde fallback (use home directly)
    #   resolve_fallback("~", "/Users/username")
    #   # => "/Users/username"
    #
    # @example Empty fallback (use home directly)
    #   resolve_fallback("", "/Users/username")
    #   # => "/Users/username"
    def resolve_fallback(fallback, home)
      return home if ["~", ""].include?(fallback)

      File.join(home, fallback)
    end

    # Resolve the global skills path, using fallbacks when needed.
    #
    # Resolves the primary global skills path relative to the base path, checking
    # if it exists. If it doesn't exist, tries each fallback path in order.
    # Returns the first existing path, or the primary path if none exist.
    #
    # This ensures that agents can gracefully handle missing directories by
    # trying alternative locations before falling back to the primary path.
    #
    # @param entry [Hash] the agent entry from YAML configuration
    # @param base_path [String] the resolved base path for this agent
    # @return [String] an absolute path to the global skills directory
    #
    # @example Primary path exists
    #   # ~/.cursor/skills exists
    #   resolve_global_skills_path({ "global_skills_path" => ".cursor/skills" }, "/Users/username")
    #   # => "/Users/username/.cursor/skills"
    #
    # @example Use fallback when primary doesn't exist
    #   # ~/.moltbot/skills doesn't exist, ~/.clawdbot/skills exists
    #   entry = {
    #     "global_skills_path" => ".moltbot/skills",
    #     "global_skills_path_fallbacks" => [".clawdbot/skills", ".moltbot/skills"]
    #   }
    #   resolve_global_skills_path(entry, "/Users/username")
    #   # => "/Users/username/.clawdbot/skills"
    #
    # @example Return primary path if none exist
    #   # No paths exist
    #   resolve_global_skills_path({ "global_skills_path" => ".unknown/skills" }, "/Users/username")
    #   # => "/Users/username/.unknown/skills"
    def resolve_global_skills_path(entry, base_path)
      primary = entry["global_skills_path"]
      fallbacks = entry["global_skills_path_fallbacks"] || []

      candidates = [primary] + fallbacks
      candidates.each do |path|
        resolved = File.expand_path(path, base_path)
        return resolved if Dir.exist?(resolved)
      end

      File.expand_path(primary, base_path)
    end

    # Detect whether an agent's paths are present based on configured paths.
    #
    # Checks each of the agent's configured detection paths. The agent is
    # considered detected if <b>any</b> of the paths exists. Detection paths
    # can be strings or hashes with different resolution strategies.
    #
    # @param agent [Agent] the agent to check for detection
    # @return [Boolean] true if any detection path exists
    #
    # @example Agent with detect paths
    #   # YAML: detect_paths: [".cursor"]
    #   agent = registry.find("cursor")
    #   detected?(agent)  # => true if ~/.cursor exists
    #
    # @example Agent with no detect paths (not detected)
    #   # YAML: detect_paths: []
    #   agent = registry.find("some-agent")
    #   detected?(agent)  # => false
    #
    # @see #detect_path Individual path detection logic
    def detected?(agent)
      entry = @data["agents"].find { |a| a["name"] == agent.name }
      return false unless entry

      detect_paths = entry["detect_paths"] || []

      detect_paths.any? do |detect_spec|
        path?(detect_spec)
      end
    end

    # Detect a path using the configured spec.
    #
    # Dispatches to the appropriate detection method based on the type
    # of the detection specification:
    #
    # * String: Check relative to home directory
    # * Hash: Check based on hash keys (cwd, base, absolute)
    # * Other: Return false
    #
    # @param spec [String, Hash] the detection specification from YAML
    # @return [Boolean] true if the path exists
    #
    # @example String detection
    #   path?(".cursor")  # => true if ~/.cursor exists
    #
    # @example Hash detection with cwd
    #   path?({ cwd: ".agent" })  # => true if ./.agent exists
    #
    # @example Hash detection with absolute
    #   path?({ absolute: "/etc/codex" })  # => true if /etc/codex exists
    #
    # @see #string_path? String detection logic
    # @see #hash_path? Hash detection logic
    def path?(spec)
      case spec
      when String
        string_path?(spec)
      when Hash
        hash_path?(spec)
      else
        false
      end
    end

    # Detect a string spec relative to the user's home directory.
    #
    # For non-empty strings, checks if the path exists relative to the user's
    # home directory. An empty string is treated as always true, which can
    # be used to mark an agent as always detected.
    #
    # @param spec [String] a path relative to the home directory
    # @return [Boolean] true if the path exists or spec is empty
    #
    # @example Normal string detection
    #   string_path?(".cursor")  # => true if ~/.cursor exists
    #
    # @example Empty string (always detected)
    #   string_path?("")  # => true
    #
    # @example Non-existent path
    #   string_path?(".does-not-exist")  # => false
    def string_path?(spec)
      spec.empty? || File.exist?(File.join(Dir.home, spec))
    end

    # Detect a hash spec with absolute/cwd/base rules.
    #
    # Handles hash-based detection specifications with different strategies:
    #
    # * +absolute+: Check the absolute path directly
    # * +cwd+: Check relative to current working directory
    # * +base+ and +path+: Check relative to a configured base path
    #
    # Only one strategy is applied per hash, in the order above.
    #
    # @param spec [Hash] a hash with detection strategy and path
    # @return [Boolean] true if the path exists
    #
    # @example Absolute path detection
    #   hash_path?({ absolute: "/etc/codex" })
    #   # => true if /etc/codex exists
    #
    # @example Current working directory detection
    #   hash_path?({ cwd: ".agent" })
    #   # => true if ./.agent exists (relative to Dir.pwd)
    #
    # @example Base path detection
    #   # Assuming home base path resolves to /Users/username
    #   hash_path?({ base: "home", path: ".codex" })
    #   # => true if /Users/username/.codex exists
    #
    # @see #base_path? Base path resolution logic
    def hash_path?(spec)
      return File.exist?(spec[:absolute]) if spec.key?(:absolute)
      return File.exist?(File.join(Dir.pwd, spec[:cwd])) if spec.key?(:cwd)
      return base_path?(spec) if spec.key?(:base) && spec.key?(:path)

      false
    end

    # Detect a path relative to a configured base path.
    #
    # Resolves a base path configuration and checks if the specified path
    # exists relative to it. If the path is empty, checks if the base path
    # directory itself exists.
    #
    # @param spec [Hash] a hash with +base+ key and optional +path+ key
    # @return [Boolean] true if the path exists
    #
    # @example Non-empty path
    #   # home base path resolves to /Users/username
    #   base_path?({ base: "home", path: ".codex" })
    #   # => true if /Users/username/.codex exists
    #
    # @example Empty path (check base directory)
    #   base_path?({ base: "home", path: "" })
    #   # => true if /Users/username exists (home directory)
    #
    # @see #resolve_base_path Base path resolution logic
    def base_path?(spec)
      base = resolve_base_path(spec[:base])
      path = spec[:path]

      if path.empty?
        Dir.exist?(base)
      else
        File.exist?(File.join(base, path))
      end
    end
  end
end
