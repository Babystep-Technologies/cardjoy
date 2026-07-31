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

  describe "duplicate prevention" do
    let(:user) { create(:user) }

    it "rejects a second contact with an email the user already has" do
      create(:contact, user:, email: "mom@example.com")
      duplicate = build(:contact, user:, name: "Mother", email: "mom@example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include(Contact::DUPLICATE_MESSAGE)
    end

    it "rejects a second contact with a phone the user already has" do
      create(:contact, user:, phone: "+14155550123")
      duplicate = build(:contact, user:, phone: "+1 (415) 555-0123")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:phone]).to include(Contact::DUPLICATE_MESSAGE)
    end

    it "matches emails case-insensitively" do
      create(:contact, user:, email: "mom@example.com")
      expect(build(:contact, user:, email: "Mom@Example.COM")).not_to be_valid
    end

    it "allows any number of contacts without an email or phone" do
      create(:contact, user:, email: nil, phone: nil)
      expect(build(:contact, user:, email: nil, phone: nil)).to be_valid
      expect(build(:contact, user:, email: "", phone: "")).to be_valid
    end

    it "lets a different user save the same person" do
      create(:contact, user:, email: "mom@example.com", phone: "+14155550123")
      other = build(:contact, email: "mom@example.com", phone: "+14155550123")

      expect(other).to be_valid
    end

    it "still saves an existing contact whose email and phone are unchanged" do
      contact = create(:contact, user:, email: "mom@example.com", phone: "+14155550123")

      contact.name = "Mother"
      expect(contact.save).to be(true)
    end
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
