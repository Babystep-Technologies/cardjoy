require "rails_helper"

RSpec.describe ContactList, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires a name" do
      list = build(:contact_list, user:, name: "")
      expect(list).not_to be_valid
      expect(list.errors.full_messages).to include("Name can't be blank")
    end

    it "rejects a second list with the same name under the same user" do
      create(:contact_list, user:, name: "Family")

      duplicate = build(:contact_list, user:, name: "Family")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include("Name #{described_class::DUPLICATE_NAME_MESSAGE}")
    end

    it "rejects a duplicate that differs only in case" do
      create(:contact_list, user:, name: "Family")

      expect(build(:contact_list, user:, name: "family")).not_to be_valid
    end

    it "allows the same name under two different users" do
      create(:contact_list, user:, name: "Family")

      expect(build(:contact_list, user: create(:user), name: "Family")).to be_valid
    end

    it "is enforced by a unique index as well as the validation" do
      create(:contact_list, user:, name: "Family")

      duplicate = build(:contact_list, user:, name: "Family")
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "strips surrounding whitespace so ' Family' can't become a second Family" do
      create(:contact_list, user:, name: "Family")

      expect(build(:contact_list, user:, name: "  Family  ")).not_to be_valid
    end

    it "rejects a name longer than the maximum" do
      expect(build(:contact_list, user:, name: "a" * (described_class::NAME_MAX_LENGTH + 1))).not_to be_valid
    end
  end

  describe "counts" do
    let(:list) { create(:contact_list, user:) }

    it "counts every contact on the list" do
      create(:contact_list_membership, contact_list: list, contact: create(:contact, user:))
      create(:contact_list_membership, contact_list: list, contact: create(:contact, :mailable, user:))

      expect(list.contacts_count).to eq(2)
    end

    it "counts only contacts with a deliverable address as mailable" do
      create(:contact_list_membership, contact_list: list, contact: create(:contact, user:))
      mailable = create(:contact, :mailable, user:)
      create(:contact_list_membership, contact_list: list, contact: mailable)

      expect(list.mailable_contacts_count).to eq(1)
      expect(list.mailable_contacts).to eq([ mailable ])
      expect(list.mailable_contacts.map(&:mailable?)).to all(be(true))
    end

    it "is zero for an empty list" do
      expect(list.contacts_count).to eq(0)
      expect(list.mailable_contacts_count).to eq(0)
    end
  end

  describe "destruction" do
    it "removes its memberships and leaves the contacts intact" do
      list = create(:contact_list, user:)
      contact = create(:contact, user:)
      create(:contact_list_membership, contact_list: list, contact:)

      expect { list.destroy! }.to change(ContactListMembership, :count).by(-1)
      expect(Contact.exists?(contact.id)).to be(true)
    end

    it "goes with its user" do
      create(:contact_list, user:)

      expect { user.destroy! }.to change(described_class, :count).by(-1)
    end
  end

  describe "Contact#contact_lists" do
    it "removes the memberships when the contact is deleted, leaving the list" do
      list = create(:contact_list, user:)
      contact = create(:contact, user:)
      create(:contact_list_membership, contact_list: list, contact:)

      expect { contact.destroy! }.to change(ContactListMembership, :count).by(-1)
      expect(described_class.exists?(list.id)).to be(true)
    end

    it "reads back the lists a contact is on" do
      contact = create(:contact, user:)
      list = create(:contact_list, user:, name: "Family")
      create(:contact_list_membership, contact_list: list, contact:)

      expect(contact.reload.contact_lists.map(&:name)).to eq([ "Family" ])
    end
  end

  describe "Contact.mailable" do
    it "matches exactly the contacts #mailable? is true for" do
      create(:contact, user:)
      create(:contact, :mailable, user:)
      # A partial address can only be written past validation, but a legacy row
      # could still hold one — the scope must agree with the predicate anyway.
      partial = build(:contact, user:, city: "San Francisco")
      partial.save(validate: false)

      expect(Contact.mailable.count).to eq(1)
      expect(user.contacts.map(&:mailable?).count(true)).to eq(1)
    end
  end
end
