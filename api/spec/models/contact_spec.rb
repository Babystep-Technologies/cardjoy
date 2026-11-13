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

  describe "mailing address" do
    it "is valid with no address fields at all" do
      contact = build(:contact)
      expect(Contact::ADDRESS_FIELDS.map { |f| contact.public_send(f) }).to all(be_nil)
      expect(contact).to be_valid
      expect(contact).not_to be_mailable
    end

    it "is valid and mailable with a complete address" do
      contact = build(:contact, :mailable)
      expect(contact).to be_valid
      expect(contact).to be_mailable
    end

    it "is mailable without the optional line 2 and region" do
      contact = build(:contact, :mailable, address_line2: nil, region: nil)
      expect(contact).to be_valid
      expect(contact).to be_mailable
    end

    it "is not mailable when any required field is missing" do
      Contact::REQUIRED_ADDRESS_FIELDS.each do |field|
        expect(build(:contact, :mailable, field => nil)).not_to be_mailable
      end
    end

    it "rejects a city on its own, naming each missing field" do
      contact = build(:contact, city: "San Francisco")

      expect(contact).not_to be_valid
      expect(contact.errors.full_messages).to contain_exactly(
        "Address line 1 #{Contact::INCOMPLETE_ADDRESS_MESSAGE}",
        "Postal code #{Contact::INCOMPLETE_ADDRESS_MESSAGE}",
        "Country code #{Contact::INCOMPLETE_ADDRESS_MESSAGE}"
      )
    end

    it "rejects a street and city with no postal code" do
      contact = build(:contact, address_line1: "123 Market St", city: "San Francisco", country_code: "US")

      expect(contact).not_to be_valid
      expect(contact.errors[:postal_code]).to include(Contact::INCOMPLETE_ADDRESS_MESSAGE)
    end

    it "requires the rest of the address when only an optional field is given" do
      expect(build(:contact, address_line2: "Apt 4")).not_to be_valid
      expect(build(:contact, region: "CA")).not_to be_valid
    end

    it "upcases the country code on write" do
      contact = create(:contact, :mailable, country_code: "us")
      expect(contact.country_code).to eq("US")
    end

    it "rejects a country code that is not two letters" do
      expect(build(:contact, :mailable, country_code: "USA")).not_to be_valid
      expect(build(:contact, :mailable, country_code: "1")).not_to be_valid
      expect(build(:contact, :mailable, country_code: "U")).not_to be_valid
    end

    it "strips surrounding whitespace from every address field" do
      contact = create(
        :contact,
        address_line1: "  123 Market St ",
        address_line2: " Apt 4 ",
        city: " San Francisco ",
        region: " CA ",
        postal_code: " 94103 ",
        country_code: " us "
      )

      expect(contact).to have_attributes(
        address_line1: "123 Market St", address_line2: "Apt 4", city: "San Francisco",
        region: "CA", postal_code: "94103", country_code: "US"
      )
    end

    it "treats a blank address field as absent rather than storing an empty string" do
      contact = create(:contact, address_line1: "", city: "   ")

      expect(contact.address_line1).to be_nil
      expect(contact.city).to be_nil
      expect(contact).to be_valid
    end

    it "lets a saved address be cleared with blanks" do
      contact = create(:contact, :mailable)

      Contact::ADDRESS_FIELDS.each { |field| contact.public_send(:"#{field}=", "") }

      expect(contact.save).to be(true)
      expect(contact.reload).not_to be_mailable
      expect(contact.city).to be_nil
    end
  end

  it "destroys its occasions when destroyed" do
    contact = create(:contact, :with_occasions)
    expect { contact.destroy }.to change(Occasion, :count).by(-2)
  end
end
