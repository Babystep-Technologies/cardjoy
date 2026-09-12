require "rails_helper"

RSpec.describe SupportTicketMailbox, type: :mailbox do
  let(:customer) { create(:user, email: "dana@example.com") }
  let(:ticket) { create(:support_ticket, :pending, user: customer) }

  it "routes a support+<token>@ address here" do
    expect(described_class).to receive_inbound_email(to: "support+#{ticket.reply_token}@cardjoy.app", from: "sender@example.com")
  end

  describe "happy path" do
    it "appends a customer message, tags it with the inbound email, and reopens the ticket" do
      processed = process(
        to: "support+#{ticket.reply_token}@cardjoy.app",
        from: customer.email,
        subject: "Re: ticket",
        body: "Thanks, that fixed it!"
      )

      expect(processed).to have_been_delivered
      expect(ticket.reload.status).to eq(SupportTicket::OPEN)
      last_message = ticket.messages.last
      expect(last_message.author_kind).to eq(SupportTicketMessage::CUSTOMER)
      expect(last_message.author_id).to eq(customer.id)
      expect(last_message.body).to eq("Thanks, that fixed it!")
      expect(last_message.inbound_email_id).to eq(processed.id.to_s)
    end
  end

  describe "an unknown or revoked token" do
    it "bounces rather than creating a message" do
      processed = process(to: "support+not-a-real-token@cardjoy.app", from: customer.email, subject: "s", body: "b")

      expect(processed).to have_bounced
    end

    it "bounces once the ticket's token has been revoked" do
      ticket.revoke_reply_token!

      processed = process(to: "support+#{ticket.reply_token}@cardjoy.app", from: customer.email, subject: "s", body: "b")

      expect(processed).to have_bounced
      expect(ticket.reload.messages).to be_empty
    end
  end

  describe "quoted-reply stripping" do
    it "keeps only the reply text above the quoted history" do
      body = <<~BODY
        Still broken on my end.

        On Fri, Sep 12, 2026 at 1:00 PM Support <support@cardjoy.app> wrote:
        > Have you tried turning it off and on again?
      BODY

      process(to: "support+#{ticket.reply_token}@cardjoy.app", from: customer.email, subject: "Re: ticket", body:)

      expect(ticket.reload.messages.last.body).to eq("Still broken on my end.")
    end
  end

  describe "an auto-responder" do
    it "is dropped without a bounce or a message, so it can never loop" do
      processed = process(
        to: "support+#{ticket.reply_token}@cardjoy.app",
        from: customer.email,
        subject: "Automatic reply: Out of office",
        body: "I am out of the office.",
        "Auto-Submitted" => "auto-replied"
      )

      expect(processed).to have_been_delivered
      expect(ticket.reload.messages).to be_empty
    end

    it "also recognizes the X-Autoreply header" do
      processed = process(
        to: "support+#{ticket.reply_token}@cardjoy.app",
        from: customer.email,
        subject: "Automatic reply",
        body: "I am out of the office.",
        "X-Autoreply" => "yes"
      )

      expect(processed).to have_been_delivered
      expect(ticket.reload.messages).to be_empty
    end
  end

  describe "the per-ticket rate limit" do
    it "stops accepting replies past the limit within the period" do
      described_class::RATE_LIMIT_MAX_MESSAGES.times do
        ticket.record_customer_reply!(user: customer, body: "reply")
      end

      processed = process(to: "support+#{ticket.reply_token}@cardjoy.app", from: customer.email, subject: "s", body: "one too many")

      expect(processed).to have_been_delivered
      expect(ticket.reload.messages.count).to eq(described_class::RATE_LIMIT_MAX_MESSAGES)
    end
  end

  describe "the body size cap" do
    it "truncates a body longer than the cap" do
      huge_body = "a" * (described_class::MAX_BODY_LENGTH + 1_000)

      process(to: "support+#{ticket.reply_token}@cardjoy.app", from: customer.email, subject: "s", body: huge_body)

      expect(ticket.reload.messages.last.body.length).to be <= described_class::MAX_BODY_LENGTH
    end
  end
end
