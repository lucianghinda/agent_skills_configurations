#!/usr/bin/env ruby
# frozen_string_literal: true

repo_root = File.expand_path("..", __dir__)
doc_dir = File.join(repo_root, "doc")
main_path = File.join(doc_dir, "AgentSkillsConfigurations.md")

unless File.exist?(main_path)
  warn "Missing #{main_path}"
  exit 1
end

md_files = Dir.glob(File.join(doc_dir, "**", "*.md"))
md_files.reject! { |path| File.expand_path(path) == File.expand_path(main_path) }

links = md_files.map do |path|
  rel_path = path.sub("#{doc_dir}/", "")
  "- [#{rel_path}](#{rel_path})"
end

content = File.read(main_path)

content = content.sub(/#Documentation\s*\n[\s\S]*\z/, "").rstrip if content.match?(/^#Documentation\s*$/)

content = content.rstrip
content << "\n\n# Documentation\n\n"
content << links.join("\n")
content << "\n"

File.write(main_path, content)
puts "Updated #{main_path} (#{links.size} links)"
