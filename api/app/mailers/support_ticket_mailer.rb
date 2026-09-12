# typed: true

class SupportTicketMailer < ApplicationMailer
  # A staff reply to a customer's support ticket (#173). Always CardJoy's own
  # branding — SupportTicket has no organization, only a user.
  #
  # Reply-To is the ticket's own support+<token>@ address (#174), so hitting
  # Reply in a mail client threads the response back onto this ticket via
  # SupportTicketMailbox instead of landing in a real inbox.
  def admin_reply(support_ticket_message)
    @message = support_ticket_message
    @ticket = @message.support_ticket
    @thread_url = "#{AppConfig.frontend_url}/support/#{@ticket.external_id}"

    mail(
      to: @ticket.user.email,
      reply_to: @ticket.reply_to_address,
      subject: "Re: #{@ticket.subject} [##{@ticket.external_id}]"
    )
  end
end
