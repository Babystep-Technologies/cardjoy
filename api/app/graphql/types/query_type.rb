# typed: true
# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :admin_cards, resolver: Queries::AdminCards
    field :admin_invitations, resolver: Queries::AdminInvitations
    field :admin_users, resolver: Queries::AdminUsers
    field :admin_promo_codes, resolver: Queries::AdminPromoCodes
    field :admin_organizations, resolver: Queries::AdminOrganizations
    field :admin_organization, resolver: Queries::AdminOrganization
    field :user_cards, resolver: Queries::UserCards
    field :card, resolver: Queries::Card
    field :styles, resolver: Queries::Styles
    field :user, resolver: Queries::User
    field :user_by_email, resolver: Queries::UserByEmail
    field :tags, resolver: Queries::Tags
    field :card_occasions, [ String ], null: false
    # Lead times the occasion reminder picker offers, so the client can't drift
    # from the model's validation.
    field :occasion_reminder_lead_day_options, [ Integer ], null: false
    field :user_promo_code, resolver: Queries::GetUserPromoCode
    field :business_metrics, resolver: Queries::BusinessMetrics
    field :daily_metrics, resolver: Queries::DailyMetrics
    field :user_invitations, resolver: Queries::UserInvitations
    field :invitation, resolver: Queries::Invitation
    field :check_rsvp, resolver: Queries::CheckRsvp
    field :check_slug_availability, resolver: Queries::CheckSlugAvailability
    field :viewer, resolver: Queries::Viewer
    field :my_contacts, resolver: Queries::MyContacts
    field :my_contact_lists, resolver: Queries::MyContactLists
    field :contact_list, resolver: Queries::ContactList
    field :upcoming_occasions, resolver: Queries::UpcomingOccasions
    field :organization_invitation_preview, resolver: Queries::OrganizationInvitationPreview
    field :my_holiday_cards, resolver: Queries::MyHolidayCards
    field :holiday_card, resolver: Queries::HolidayCard
    field :holiday_card_templates, resolver: Queries::HolidayCardTemplates
    field :holiday_card_stickers, resolver: Queries::HolidayCardStickers
    field :my_postage_ledger, resolver: Queries::MyPostageLedger

    def card_occasions
      ::Card::OCCASIONS
    end

    def occasion_reminder_lead_day_options
      ::Occasion::REMINDER_LEAD_DAY_OPTIONS
    end
  end
end
