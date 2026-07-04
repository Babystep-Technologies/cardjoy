# scripts/generate_promo_code.rb
# bin/rails runner scripts/generate_promo_code.rb

puts "📣 Let's create a promo code!"
puts "------------------------------"

print "🌍 Which Rails environment? (development/production/test) [default: development]: "
env_input = STDIN.gets.chomp.strip
env = env_input.empty? ? "development" : env_input

ENV["RAILS_ENV"] = env
require_relative "../config/environment"

puts "🔧 Running in Rails.env = #{Rails.env}"
if Rails.env.production?
  puts "⚠️  You are modifying production data! Are you sure? (y/N): "
  confirm = STDIN.gets.chomp.strip.downcase
  exit unless confirm == "y"
end

puts "------------------------------"

print "🔤 Promo code name (e.g. SPRING25): "
code = STDIN.gets.chomp.strip.downcase

if PromoCode.exists?(code: code)
  puts "❌ Promo code already exists: #{code.upcase}"
  exit 1
end

print "💎 Credit amount to issue (e.g. 5): "
credit_amount = STDIN.gets.chomp.to_i
if credit_amount <= 0
  puts "❌ Invalid credit amount"
  exit 1
end

print "🔁 Usage limit (default: 1): "
usage_limit_input = STDIN.gets.chomp
usage_limit = usage_limit_input.empty? ? 1 : usage_limit_input.to_i

print "📅 Expiration date? (YYYY-MM-DD or leave blank): "
expires_input = STDIN.gets.chomp.strip
expires_at = expires_input.empty? ? nil : Time.zone.parse(expires_input)

print "👤 Assign to specific user? (email or leave blank for general promo): "
user_email_input = STDIN.gets.chomp.strip
user = nil
if !user_email_input.empty?
  user = User.find_by(email: user_email_input.downcase)
  if user.nil?
    puts "❌ User not found with email: #{user_email_input}"
    exit 1
  else
    puts "✅ Found user: #{user.name} (#{user.email})"
    # Force usage_limit to 1 for user-specific promo codes
    usage_limit = 1
    puts "ℹ️  Usage limit set to 1 for user-specific promo code"
  end
end

promo = PromoCode.create!(
  code: code,
  credit_amount: credit_amount,
  usage_limit: usage_limit,
  expires_at: expires_at,
  user: user
)

puts "\n✅ Promo code created!"
puts "------------------------------"
puts "🔤 Code:         #{promo.code.upcase}"
puts "💎 Credit:       #{promo.credit_amount}"
puts "🔁 Usage limit:  #{promo.usage_limit}"
puts "📅 Expires at:   #{promo.expires_at || 'Never'}"
puts "👤 Assigned to:  #{promo.user ? "#{promo.user.name} (#{promo.user.email})" : 'General (anyone can use)'}"
puts "🌍 Environment:  #{Rails.env}"
