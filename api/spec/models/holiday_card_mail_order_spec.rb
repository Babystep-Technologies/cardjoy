require "rails_helper"

# One physical piece of mail (#148). The parts with teeth are the recipient
# snapshot outliving the contact, and the refund being safe to attempt twice.
RSpec.describe HolidayCardMailOrder do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid as the factory builds it" do
      expect(build(:holiday_card_mail_order)).to be_valid
    end

    it "rejects a status outside STATUSES" do
      order = build(:holiday_card_mail_order, status: "in_the_post")

      expect(order).not_to be_valid
      expect(order.errors[:status]).to be_present
    end

    it "rejects a duplicate idempotency_key" do
      create(:holiday_card_mail_order, idempotency_key: "duplicate")
      order = build(:holiday_card_mail_order, idempotency_key: "duplicate")

      expect(order).not_to be_valid
      expect(order.errors[:idempotency_key]).to be_present
    end

    # A rate-card bug that priced a piece at nothing would sail past a presence
    # check and mail for free.
    it "rejects a zero charge" do
      order = build(:holiday_card_mail_order, charged_cents: 0)

      expect(order).not_to be_valid
      expect(order.errors[:charged_cents]).to be_present
    end
  end

  describe ".snapshot_for" do
    it "captures the name and every address field the contact has" do
      contact = create(:contact, :mailable, name: "Ada Lovelace")

      expect(described_class.snapshot_for(contact)).to eq(
        "name" => "Ada Lovelace",
        "address_line1" => "123 Market St",
        "address_line2" => "Apt 4",
        "city" => "San Francisco",
        "region" => "CA",
        "postal_code" => "94103",
        "country_code" => "US"
      )
    end

    it "omits fields the contact doesn't have rather than storing nulls" do
      contact = create(:contact, :mailable, address_line2: nil, region: nil)

      expect(described_class.snapshot_for(contact).keys).not_to include("address_line2", "region")
    end
  end

  describe "the snapshot outliving the contact" do
    it "survives the contact's address being edited afterwards" do
      contact = create(:contact, :mailable, user:, name: "Ada Lovelace")
      order = create(:holiday_card_mail_order, user:, recipient: contact)

      contact.update!(address_line1: "999 Somewhere Else", name: "Ada L.")

      expect(order.reload.recipient_name).to eq("Ada Lovelace")
      expect(order.recipient_snapshot["address_line1"]).to eq("123 Market St")
    end

    # The order is a record of money spent on a card that is physically in the
    # post. Deleting the contact must not erase it.
    it "survives the contact being deleted, leaving contact_id null" do
      contact = create(:contact, :mailable, user:, name: "Ada Lovelace")
      order = create(:holiday_card_mail_order, user:, recipient: contact)

      contact.destroy!

      expect(order.reload).to be_persisted
      expect(order.contact_id).to be_nil
      expect(order.recipient_name).to eq("Ada Lovelace")
      expect(order.recipient_snapshot["postal_code"]).to eq("94103")
    end
  end

  describe "#mark_submitted!" do
    let(:order) { create(:holiday_card_mail_order, user:) }

    it "records the id, the time, and our status" do
      freeze_time do
        order.mark_submitted!(postgrid_id: "postcard_abc", postgrid_status: "ready")

        expect(order.reload).to have_attributes(
          postgrid_id: "postcard_abc",
          status: described_class::SUBMITTED,
          submitted_at: Time.current
        )
      end
    end

    it "translates PostGrid's vocabulary into ours rather than storing theirs" do
      order.mark_submitted!(postgrid_id: "postcard_abc", postgrid_status: "processed_for_delivery")

      expect(order.reload.status).to eq(described_class::PROCESSED_FOR_DELIVERY)
    end

    # Their release notes are not our migration.
    it "falls back to submitted for a status we don't recognise" do
      order.mark_submitted!(postgrid_id: "postcard_abc", postgrid_status: "some_new_postgrid_state")

      expect(order.reload.status).to eq(described_class::SUBMITTED)
    end
  end

  describe "#fail_and_refund!" do
    let(:order) { create(:holiday_card_mail_order, user:, charged_cents: 112) }

    before { user.refund_postage!(cents: 500, reason: "top_up", event_kind: "postage_purchased") }

    it "marks the order failed, records the reason, and refunds exactly charged_cents" do
      expect(order.fail_and_refund!(reason: "Undeliverable")).to be(true)

      expect(order.reload).to have_attributes(status: described_class::FAILED, failure_reason: "Undeliverable")
      expect(user.reload.postage_balance_cents).to eq(500 + 112)
      expect(user.postage_credits.where(amount_cents: 112).last.reason).to eq("holiday_card_mail_refund")
    end

    # The acceptance criterion with teeth. The guard is the conditional UPDATE
    # on `status`, so the second call finds nothing to claim.
    it "refunds once even when called twice" do
      order.fail_and_refund!(reason: "Undeliverable")

      expect(order.fail_and_refund!(reason: "Undeliverable again")).to be(false)

      expect(user.reload.postage_balance_cents).to eq(500 + 112)
      expect(order.reload.failure_reason).to eq("Undeliverable")
    end

    it "refuses to refund an order that already succeeded" do
      order.mark_submitted!(postgrid_id: "postcard_abc")

      expect(order.fail_and_refund!(reason: "Too late")).to be(false)

      expect(user.reload.postage_balance_cents).to eq(500)
      expect(order.reload.status).to eq(described_class::SUBMITTED)
    end
  end

  # The behaviour lives in spec/requests/postgrid_webhooks_spec.rb, which
  # exercises it the way it actually happens. What's here is the invariant the
  # ordering rests on (#149).
  describe "#apply_postgrid_update!" do
    let(:order) { create(:holiday_card_mail_order, :submitted, user:) }

    # A status missing from STATUS_RANK raises KeyError on the next webhook.
    # The two lists have to move together.
    it "ranks every status" do
      expect(described_class::STATUS_RANK.keys).to match_array(described_class::STATUSES)
    end

    it "reports what it did, for the webhook log" do
      expect(order.apply_postgrid_update!(postgrid_status: "printing")).to eq(:advanced)
      expect(order.apply_postgrid_update!(postgrid_status: "printing")).to eq(:ignored)
      expect(order.apply_postgrid_update!(postgrid_status: "entered_mail_stream")).to eq(:unknown_status)
    end
  end
end
