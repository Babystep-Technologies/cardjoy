# typed: false

require "rails_helper"

RSpec.describe ScrubGuestEmailsJob, type: :job do
  def claim_on(list)
    item = create(:wish_list_item, wish_list: list)
    create(:wish_list_reservation, wish_list_item: item)
  end

  it "erases emails a week after the event but keeps the claim and the guest's name" do
    claim = claim_on(create(:wish_list, :standalone, event_date: Date.current - 8))

    described_class.new.perform

    claim.reload
    expect(claim.guest_email).to be_nil
    expect(claim.guest_name).to be_present
  end

  it "leaves emails on registries still inside the window or without a date" do
    recent = claim_on(create(:wish_list, :standalone, event_date: Date.current - 3))
    undated = claim_on(create(:wish_list, :standalone, event_date: nil))

    described_class.new.perform

    expect(recent.reload.guest_email).to be_present
    expect(undated.reload.guest_email).to be_present
  end

  it "does not stop an archived registry's claim from being saved after the scrub" do
    claim = claim_on(create(:wish_list, :standalone, event_date: Date.current - 8))
    described_class.new.perform

    expect(claim.reload.update(purchased_at: Time.current)).to be(true)
  end
end
