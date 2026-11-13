# typed: false

require "rails_helper"

RSpec.describe WishListMailer, type: :mailer do
  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return("https://cardjoy.test")
  end

  let(:registry) { create(:wish_list, :standalone, title: "Sam's 30th") }
  let(:item) { create(:wish_list_item, wish_list: registry, title: "Cast-iron pan", url: "https://shop.test/pan", store: "shop.test") }
  let(:reservation) { create(:wish_list_reservation, wish_list_item: item, guest_name: "Alex", guest_email: "alex@example.com") }

  describe "#claim_confirmation" do
    subject(:mail) { described_class.claim_confirmation(reservation) }

    it "goes to the guest with a manage link carrying their token" do
      expect(mail.to).to eq([ "alex@example.com" ])
      expect(mail.subject).to eq("You're getting Cast-iron pan")
      expect(mail.body.encoded).to include("https://cardjoy.test/registry/#{registry.external_id}?claim=#{reservation.token}")
      expect(mail.body.encoded).to include("https://shop.test/pan")
    end

    it "links an invitation's wish list to its own page" do
      invitation_list = create(:wish_list)
      booked = create(:wish_list_reservation, wish_list_item: create(:wish_list_item, wish_list: invitation_list))

      body = described_class.claim_confirmation(booked).body.encoded

      expect(body).to include("/invitation/#{invitation_list.invitation.external_id}/wishlist?claim=#{booked.token}")
    end
  end

  describe "#claim_reminder" do
    subject(:mail) { described_class.claim_reminder(reservation) }

    it "asks whether they bought it and says when it will be released" do
      expect(mail.subject).to eq("Did you get Cast-iron pan?")
      expect(mail.body.encoded).to include("7 days")
      expect(mail.body.encoded).to include("?claim=#{reservation.token}")
    end
  end

  describe "#claim_released" do
    subject(:mail) do
      described_class.claim_released(
        guest_name: "Alex", guest_email: "alex@example.com", item_title: "Cast-iron pan", wish_list: registry
      )
    end

    it "tells the guest the item is free again, without a token" do
      expect(mail.to).to eq([ "alex@example.com" ])
      expect(mail.subject).to eq("We've freed up Cast-iron pan")
      expect(mail.body.encoded).to include("https://cardjoy.test/registry/#{registry.external_id}")
      expect(mail.body.encoded).not_to include("claim=")
    end
  end
end
