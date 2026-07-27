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

  it "allows a blank phone but rejects one that isn't E.164" do
    expect(build(:contact, phone: nil)).to be_valid
    expect(build(:contact, phone: "")).to be_valid
    expect(build(:contact, phone: "+14155550123")).to be_valid
    expect(build(:contact, phone: "555-0123")).not_to be_valid
    expect(build(:contact, phone: "+0155501234")).not_to be_valid
  end

  it "normalizes punctuation out of a phone number before validating" do
    contact = create(:contact, phone: "+1 (415) 555-0123")
    expect(contact.phone).to eq("+14155550123")
  end

  it "rejects notes longer than the maximum" do
    expect(build(:contact, notes: "a" * Contact::NOTES_MAX_LENGTH)).to be_valid
    expect(build(:contact, notes: "a" * (Contact::NOTES_MAX_LENGTH + 1))).not_to be_valid
  end

  it "destroys its occasions when destroyed" do
    contact = create(:contact, :with_occasions)
    expect { contact.destroy }.to change(Occasion, :count).by(-2)
  end
end
