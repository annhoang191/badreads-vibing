#!/usr/bin/env ruby
# PreToolUse (Edit|Write|Read): refuse to touch secret files.
# Exit 2 blocks the tool call; the stderr message is shown to Claude.
require "json"

input = JSON.parse($stdin.read) rescue exit(0)
path = input.dig("tool_input", "file_path").to_s
exit 0 if path.empty?

root = ENV.fetch("CLAUDE_PROJECT_DIR", Dir.pwd)
rel = path.start_with?(root) ? path.delete_prefix("#{root}/") : path
name = File.basename(rel)

ALLOWED = %w[frontend/.env.development].freeze

secret =
  rel.end_with?("config/master.key") ||
  rel.match?(%r{config/credentials/[^/]+\.key\z}) ||
  (name.start_with?(".env") && !ALLOWED.include?(rel))

if secret
  warn "Blocked: #{rel} holds secrets. Use Rails credentials (bin/rails credentials:edit) " \
       "and don't read or write key/.env files. See CLAUDE.md."
  exit 2
end
