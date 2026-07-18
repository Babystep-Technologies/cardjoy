require "rails_helper"

RSpec.describe Contact, type: :model do
  it "requires a name" do
    contact = build(:contact, name: nil)
    expect(contact).not_to be_valid
    expect(contact.errors[:name]).to be_present
  end

  it "allows a blank email but rejects a malformed one" do
    expect(build(:contact, email: nil)).to be_valid
    expect(build(:contact, email: "")).to be_valid
    expect(build(:contact, email: "not-an-email")).not_to be_valid
  end

  it "destroys its occasions when destroyed" do
    contact = create(:contact, :with_occasions)
    expect { contact.destroy }.to change(Occasion, :count).by(-2)
  end
end
