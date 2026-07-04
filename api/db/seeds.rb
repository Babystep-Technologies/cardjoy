# Force Active Storage to be fully loaded
require "active_storage/engine"

# Fully eager-load after loading Active Storage
Rails.application.eager_load!

# Reload Style to ensure attachments are registered
Object.send(:remove_const, :Style)
load Rails.root.join("app/models/style.rb")

puts "🌱 Seeding Background Colors..."
background_colors = [
  { name: "Soft Ivory", value: "#FDFCF9" },
  { name: "Blush Pink", value: "#FDEDED" },
  { name: "Sky Blue", value: "#E0F2FE" },
  { name: "Lavender Mist", value: "#EDE9FE" },
  { name: "Sage Green", value: "#E8F5E9" },
  { name: "Lemon Cream", value: "#FFF9DB" },
  { name: "Light Coral", value: "#FFE5E0" },
  { name: "Porcelain", value: "#F7F7F8" },
  { name: "Mist Gray", value: "#EDF1F5" }
]

background_colors.each do |color|
  Style.find_or_create_by!(
    name: color[:name],
    kind: "background_color",
    source: color[:value]
  )
end
puts "✅ Seeded #{background_colors.count} background cover styles."

puts "🌱 Seeding font Colors..."
font_colors = [
  { name: "Charcoal", value: "#1E293B" },
  { name: "Slate Gray", value: "#334155" },
  { name: "Rich Navy", value: "#0F172A" },
  { name: "Mocha", value: "#3B2F2F" },
  { name: "Midnight Plum", value: "#3D1D4A" },
  { name: "Forest Green", value: "#1B4332" },
  { name: "Warm Brown", value: "#5C4033" },
  { name: "Ink Black", value: "#111111" },
  { name: "Cocoa Gray", value: "#4B4B4B" }
]

font_colors.each do |color|
  Style.find_or_create_by!(
    name: color[:name],
    kind: "text_color",
    source: color[:value]
  )
end
puts "✅ Seeded #{font_colors.count} font color styles."
