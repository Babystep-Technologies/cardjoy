# Preview at http://localhost:3000/rails/mailers/occasion_reminder_mailer/upcoming_occasion
class OccasionReminderMailerPreview < ActionMailer::Preview
  def upcoming_occasion
    user = User.new(name: "Alex", email: "alex@example.com")
    contact = Contact.new(name: "Jordan", user: user)
    occasion = Occasion.new(
      kind: "Birthday",
      occurs_on: Date.current + 6.days,
      recurring: true,
      contact: contact
    )
    OccasionReminderMailer.upcoming_occasion(occasion)
  end
end
