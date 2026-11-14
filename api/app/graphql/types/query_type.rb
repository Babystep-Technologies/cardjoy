# typed: true
# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :admin_cards, resolver: Queries::AdminCards
    field :admin_invitations, resolver: Queries::AdminInvitations
    field :admin_registries, resolver: Queries::AdminRegistries
    field :admin_users, resolver: Queries::AdminUsers
    field :admin_promo_codes, resolver: Queries::AdminPromoCodes
    field :admin_organizations, resolver: Queries::AdminOrganizations
    field :admin_organization, resolver: Queries::AdminOrganization
    field :admin_metrics, resolver: Queries::AdminMetrics
    field :admin_one_on_one_metrics, resolver: Queries::AdminOneOnOneMetrics
    field :admin_annual_goals, resolver: Queries::AdminAnnualGoals
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
    field :my_registries, resolver: Queries::MyRegistries
    field :registry, resolver: Queries::Registry
    field :wish_list_claim, resolver: Queries::WishListClaim
    field :my_support_tickets, resolver: Queries::MySupportTickets
    field :support_ticket, resolver: Queries::SupportTicket
    field :admin_support_tickets, resolver: Queries::AdminSupportTickets
    field :admin_support_ticket, resolver: Queries::AdminSupportTicket

    def card_occasions
      ::Card::OCCASIONS
    end

    def occasion_reminder_lead_day_options
      ::Occasion::REMINDER_LEAD_DAY_OPTIONS
    end
  end
end
