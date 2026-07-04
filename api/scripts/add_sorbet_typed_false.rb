require 'find'

def add_typed_false_to_file(file)
  lines = File.readlines(file)
  return if lines[0]&.match?(/^#\s*typed:/)

  File.open(file, "w") do |f|
    f.puts "# typed: false"
    lines.each { |line| f.puts line }
  end

  puts "✔ Added '# typed: false' to: #{file}"
end

# Validate input
dir = ARGV[0]
unless dir && Dir.exist?(dir)
  puts "Usage: ruby bin/add_typed_false.rb <directory>"
  exit(1)
end

Find.find(dir) do |path|
  next unless path.end_with?(".rb")
  add_typed_false_to_file(path)
end
