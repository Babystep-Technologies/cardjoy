# typed: true

class SupportTicketMailer < ApplicationMailer
  # A staff reply to a customer's support ticket (#173). Always CardJoy's own
  # branding — SupportTicket has no organization, only a user.
  #
  # No Reply-To of its own yet, which leaves the header at ApplicationMailer's
  # default (none): #174 replaces this with a per-ticket addressed token so a
  # customer's reply comes back into the thread instead of a real inbox.
  def admin_reply(support_ticket_message)
    @message = support_ticket_message
    @ticket = @message.support_ticket
    @thread_url = "#{AppConfig.frontend_url}/support/#{@ticket.external_id}"

    mail(
      to: @ticket.user.email,
      subject: "Re: #{@ticket.subject} [##{@ticket.external_id}]"
    )
  end
end
