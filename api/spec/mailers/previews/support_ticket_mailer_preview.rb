# Preview at http://localhost:3000/rails/mailers/support_ticket_mailer/admin_reply
class SupportTicketMailerPreview < ActionMailer::Preview
  def admin_reply
    customer = User.new(name: "Dana Host", email: "dana@example.com")
    ticket = SupportTicket.new(
      subject: "Can't redeem my promo code",
      category: "Credits & promos",
      status: "pending",
      external_id: "PREVIEW",
      user: customer
    )
    message = SupportTicketMessage.new(
      support_ticket: ticket,
      author_kind: "admin",
      body: "Thanks for flagging this — the code had already been redeemed on a previous " \
        "order. I've issued a fresh one to your account, good for the next 30 days."
    )

    SupportTicketMailer.admin_reply(message)
  end
end
