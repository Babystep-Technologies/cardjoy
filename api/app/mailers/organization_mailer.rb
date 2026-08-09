# typed: true

class OrganizationMailer < ApplicationMailer
  # The join link an invited person clicks. Uses AppConfig.frontend_url rather
  # than reading credentials directly, so the URL is correct in every
  # environment — the older mailers' `credentials.dig(:frontend_url)` is nil in
  # local development.
  def invitation(organization_invitation)
    @invitation = organization_invitation
    @organization = organization_invitation.organization
    @inviter = organization_invitation.invited_by
    @join_url = "#{AppConfig.frontend_url}/organizations/join?token=#{organization_invitation.token}"

    mail(
      to: organization_invitation.email,
      subject: "#{@inviter.name} invited you to join #{@organization.name} on CardJoy"
    )
  end
end
