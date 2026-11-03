#!/usr/bin/env ruby
# PostToolUse (Edit|Write): auto-format the file that was just changed.
# Never fails the edit: formatter errors are ignored (bin/check and CI catch real problems).
require "json"

input = JSON.parse($stdin.read) rescue exit(0)
path = input.dig("tool_input", "file_path").to_s
exit 0 if path.empty? || !File.file?(path)

root = ENV.fetch("CLAUDE_PROJECT_DIR", Dir.pwd)
rel = path.delete_prefix("#{root}/")

case rel
when %r{\Abackend/.+\.(rb|rake)\z}
  Dir.chdir(File.join(root, "backend")) do
    system("bin/rubocop", "-a", "--force-exclusion", "--format", "quiet", path, out: File::NULL, err: File::NULL)
  end
when %r{\Afrontend/src/.+\.(ts|vue|css)\z}
  Dir.chdir(File.join(root, "frontend")) do
    system("npx", "--no-install", "prettier", "--write", "--log-level", "silent", path, out: File::NULL, err: File::NULL)
  end
end
exit 0
