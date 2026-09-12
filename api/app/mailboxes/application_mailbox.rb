# typed: true

class ApplicationMailbox < ActionMailbox::Base
  # A customer's emailed reply to a SupportTicket (#174) — see
  # SupportTicket#reply_to_address for how the address is minted, and
  # SupportTicketMailbox for what happens once it lands here.
  routing /^support\+/i => :support_ticket
end
