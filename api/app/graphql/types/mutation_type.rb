# typed: true
# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :sign_in, mutation: Mutations::SignIn
    field :sign_up, mutation: Mutations::SignUp
    field :google_oauth_sign_in, mutation: Mutations::GoogleOauthSignIn
    field :google_admin_sign_in, mutation: Mutations::GoogleAdminSignIn
    field :send_password_reset, mutation: Mutations::SendPasswordReset
    field :create_card, mutation: Mutations::CreateCard
    field :create_one_on_one_card, mutation: Mutations::CreateOneOnOneCard
    field :upsert_message, mutation: Mutations::UpsertMessage
    field :delete_card, mutation: Mutations::DeleteCard
    field :update_card, mutation: Mutations::UpdateCard
    field :invite_to_card, mutation: Mutations::InviteToCard
    field :deliver_card, mutation: Mutations::DeliverCard
    field :cancel_scheduled_delivery, mutation: Mutations::CancelScheduledDelivery
    field :create_stripe_checkout_session, mutation: Mutations::CreateStripeCheckoutSession
    field :redeem_promo_code, mutation: Mutations::RedeemPromoCode
    field :issue_user_promo_code, mutation: Mutations::IssueUserPromoCode
    field :create_general_promo_code, mutation: Mutations::CreateGeneralPromoCode
    field :update_cover_style, mutation: Mutations::UpdateCoverStyle
    field :archive_cover_style, mutation: Mutations::ArchiveCoverStyle
    field :create_cover_style, mutation: Mutations::CreateCoverStyle
    field :resend_confirmation_code, mutation: Mutations::ResendConfirmationCode
    field :confirm_email, mutation: Mutations::ConfirmEmail
    field :toggle_lock_card, mutation: Mutations::ToggleLockCard
    field :reset_password, mutation: Mutations::ResetPassword
    field :update_card_by_admin, mutation: Mutations::UpdateCardByAdmin
    field :flag_card_message, mutation: Mutations::FlagCardMessage
    field :generate_qr_code, mutation: Mutations::GenerateQrCode
    field :create_support_request, mutation: Mutations::CreateSupportRequest
    field :react_to_message, mutation: Mutations::ReactToMessage
    field :remove_card_cover_image, mutation: Mutations::RemoveCardCoverImage
    field :create_invitation, mutation: Mutations::CreateInvitation
    field :create_invitation_draft, mutation: Mutations::CreateInvitationDraft
    field :update_invitation, mutation: Mutations::UpdateInvitation
    field :approve_invitation_draft, mutation: Mutations::ApproveInvitationDraft
    field :upsert_wish_list, mutation: Mutations::UpsertWishList
    field :create_rsvp, mutation: Mutations::CreateRsvp
    field :connect_slack_account, mutation: Mutations::ConnectSlackAccount
    field :create_contact, mutation: Mutations::CreateContact
    field :update_contact, mutation: Mutations::UpdateContact
    field :delete_contact, mutation: Mutations::DeleteContact
    field :create_occasion, mutation: Mutations::CreateOccasion
    field :update_occasion, mutation: Mutations::UpdateOccasion
    field :delete_occasion, mutation: Mutations::DeleteOccasion
    field :create_organization, mutation: Mutations::CreateOrganization
    field :update_organization, mutation: Mutations::UpdateOrganization
    field :delete_organization, mutation: Mutations::DeleteOrganization
    field :switch_organization, mutation: Mutations::SwitchOrganization
    field :invite_to_organization, mutation: Mutations::InviteToOrganization
    field :accept_organization_invitation, mutation: Mutations::AcceptOrganizationInvitation
    field :revoke_organization_invitation, mutation: Mutations::RevokeOrganizationInvitation
    field :update_organization_membership, mutation: Mutations::UpdateOrganizationMembership
    field :remove_organization_member, mutation: Mutations::RemoveOrganizationMember
    field :leave_organization, mutation: Mutations::LeaveOrganization
    field :allocate_organization_credits, mutation: Mutations::AllocateOrganizationCredits
  end
end
