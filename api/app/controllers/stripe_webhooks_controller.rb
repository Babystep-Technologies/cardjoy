# typed: true

class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)

    case event["type"]
    when "checkout.session.completed"
      session = event["data"]["object"]
      handle_checkout_success(session)
    when "charge.dispute.closed"
      dispute = event["data"]["object"]
      handle_dispute_closed(dispute)
    end

    render json: { message: "success" }
  rescue => e
    Rails.logger.error("[StripeWebhook] Error: #{e.message}")
    render json: { error: e.message }, status: 400
  end

  private

  def handle_checkout_success(session)
    user = User.find_by(id: session.metadata.user_id)
    return unless user

    # Save Stripe customer ID if not already set
    if session["customer"].present? && user.stripe_customer_id.blank?
      user.update!(stripe_customer_id: session["customer"])
    end

    credits_to_issue = case session["amount_total"]
    when 300 then 1
    when 1200 then 5
    when 2000 then 10
    else 0
    end
    return if credits_to_issue.zero?

    organization_id = session["metadata"]["organization_id"]
    credited = if organization_id.present?
      credit_organization(organization_id, session, credits_to_issue)
    else
      credit_user(user, session, credits_to_issue)
    end
    # Nothing was written — an unknown organization, or a redelivery we've
    # already banked. Either way the buyer shouldn't get a second receipt.
    return unless credited

    UserMailer.purchase_confirmation_email(user, credits_to_issue).deliver_later
  end

  def credit_user(user, session, credits_to_issue)
    Credit.create!(
      user: user,
      amount: credits_to_issue,
      reason: "purchase",
      stripe_session_id: session["id"],
      events: [
        {
          event_kind: "credit_purchased",
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: {
            stripe_session_id: session["id"],
            stripe_customer_id: session["customer"],
            amount: credits_to_issue
          }
        }
      ]
    )
  end

  # The purchase lands in the organization's shared pool, not the buyer's
  # personal balance. Stripe redelivers events on its own schedule, so the
  # session id doubles as the idempotency key.
  def credit_organization(organization_id, session, credits_to_issue)
    organization = Organization.find_by(id: organization_id)
    unless organization
      Rails.logger.error("[StripeWebhook] Unknown organization #{organization_id} for session #{session['id']}")
      return
    end

    return if OrganizationCredit.exists?(
      organization: organization,
      reason: "purchase",
      stripe_session_id: session["id"]
    )

    OrganizationCredit.create!(
      organization: organization,
      amount: credits_to_issue,
      reason: "purchase",
      stripe_session_id: session["id"],
      events: [
        {
          event_kind: "org_credit_purchased",
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: {
            stripe_session_id: session["id"],
            stripe_customer_id: session["customer"],
            purchased_by_user_id: session.metadata.user_id,
            amount: credits_to_issue
          }
        }
      ]
    )
  end

  def handle_dispute_closed(dispute)
    return unless dispute["status"] == "lost"

    charge_id = dispute["charge"]
    charge = Stripe::Charge.retrieve(charge_id)

    stripe_session_id = charge.metadata["checkout_session_id"]
    return unless stripe_session_id

    # An org purchase reverses against the pool and must leave every user's
    # ledger alone, so check that side first.
    organization_credit = OrganizationCredit.find_by(stripe_session_id: stripe_session_id, reason: "purchase")
    if organization_credit
      reverse_organization_credit(organization_credit, dispute, charge_id)
      return
    end

    credit = Credit.find_by(stripe_session_id: stripe_session_id)
    return unless credit && credit.user

    # Prevent duplicate reversal
    existing_reversal = Credit.where(
      user: credit.user,
      reason: "chargeback"
    ).where("events @> ?", [ {
      event_kind: "credit_reversed_due_to_chargeback",
      event_data: { original_credit_id: credit.id }
    } ].to_json).exists?

    return if existing_reversal

    Credit.create!(
      user: credit.user,
      amount: -T.must(credit.amount),
      reason: "chargeback",
      stripe_session_id: stripe_session_id,
      events: [
        {
          event_kind: "credit_reversed_due_to_chargeback",
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: {
            original_credit_id: credit.id,
            stripe_charge_id: charge_id,
            stripe_dispute_id: dispute["id"]
          }
        }
      ]
    )
  end

  def reverse_organization_credit(organization_credit, dispute, charge_id)
    organization = organization_credit.organization
    return unless organization

    # Same duplicate guard as the personal ledger: one reversal per original row.
    existing_reversal = OrganizationCredit.where(
      organization: organization,
      reason: "chargeback"
    ).where("events @> ?", [ {
      event_kind: "org_credit_reversed_due_to_chargeback",
      event_data: { original_credit_id: organization_credit.id }
    } ].to_json).exists?

    return if existing_reversal

    OrganizationCredit.create!(
      organization: organization,
      amount: -T.must(organization_credit.amount),
      reason: "chargeback",
      stripe_session_id: organization_credit.stripe_session_id,
      events: [
        {
          event_kind: "org_credit_reversed_due_to_chargeback",
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: {
            original_credit_id: organization_credit.id,
            stripe_charge_id: charge_id,
            stripe_dispute_id: dispute["id"]
          }
        }
      ]
    )
  end
end
