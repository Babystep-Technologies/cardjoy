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
    field :upsert_message, mutation: Mutations::UpsertMessage
    field :delete_card, mutation: Mutations::DeleteCard
    field :update_card, mutation: Mutations::UpdateCard
    field :invite_to_card, mutation: Mutations::InviteToCard
    field :create_stripe_checkout_session, mutation: Mutations::CreateStripeCheckoutSession
    field :redeem_promo_code, mutation: Mutations::RedeemPromoCode
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
    field :create_rsvp, mutation: Mutations::CreateRsvp
    field :connect_slack_account, mutation: Mutations::ConnectSlackAccount
  end
end
