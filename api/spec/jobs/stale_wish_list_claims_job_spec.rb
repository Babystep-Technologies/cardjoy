# typed: false

require "rails_helper"

RSpec.describe StaleWishListClaimsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:item) { create(:wish_list_item) }

  def claim(age:, **attrs)
    create(:wish_list_reservation, wish_list_item: item, created_at: age.ago, **attrs)
  end

  describe "reminders" do
    it "reminds a guest whose claim is old and unbought, and stamps it" do
      stale = claim(age: 15.days)

      expect { described_class.new.perform }
        .to have_enqueued_mail(WishListMailer, :claim_reminder).with(stale)

      expect(stale.reload.reminded_at).to be_present
    end

    it "leaves a fresh claim alone" do
      claim(age: 3.days)

      expect { described_class.new.perform }.not_to have_enqueued_mail(WishListMailer, :claim_reminder)
    end

    it "never reminds twice" do
      claim(age: 15.days)
      described_class.new.perform

      expect { described_class.new.perform }.not_to have_enqueued_mail(WishListMailer, :claim_reminder)
    end

    it "never reminds about a purchase" do
      claim(age: 30.days, purchased_at: 20.days.ago)

      expect { described_class.new.perform }.not_to have_enqueued_mail(WishListMailer, :claim_reminder)
    end
  end

  describe "releases" do
    it "releases a claim that stayed unbought a week after its reminder, and tells the guest" do
      lapsed = claim(age: 25.days, reminded_at: 8.days.ago)

      expect { described_class.new.perform }
        .to have_enqueued_mail(WishListMailer, :claim_released)
        .with(hash_including(guest_email: lapsed.guest_email, item_title: item.title))

      expect(WishListReservation.exists?(lapsed.id)).to be(false)
      expect(item.reload).not_to be_claimed
    end

    it "gives a reminded claim the full week first" do
      reminded = claim(age: 20.days, reminded_at: 3.days.ago)

      described_class.new.perform

      expect(WishListReservation.exists?(reminded.id)).to be(true)
    end

    it "never releases a purchase, however old" do
      bought = claim(age: 60.days, reminded_at: 40.days.ago, purchased_at: 35.days.ago)

      described_class.new.perform

      expect(WishListReservation.exists?(bought.id)).to be(true)
    end

    it "does not remind a claim in the same run that releases others" do
      claim(age: 25.days, reminded_at: 8.days.ago)

      expect { described_class.new.perform }.not_to have_enqueued_mail(WishListMailer, :claim_reminder)
    end
  end
end
