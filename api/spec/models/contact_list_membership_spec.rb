require "rails_helper"

RSpec.describe ContactListMembership, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:contact_list, user:) }

  it "joins a list and a contact owned by the same user" do
    expect(build(:contact_list_membership, contact_list: list, contact: create(:contact, user:))).to be_valid
  end

  describe "cross-user integrity" do
    it "rejects a contact belonging to a different user" do
      membership = build(:contact_list_membership, contact_list: list, contact: create(:contact))

      expect(membership).not_to be_valid
      expect(membership.errors.full_messages).to include("Contact #{described_class::CROSS_USER_MESSAGE}")
    end

    it "rejects it on update too, not just on create" do
      membership = create(:contact_list_membership, contact_list: list, contact: create(:contact, user:))

      membership.contact = create(:contact)
      expect(membership).not_to be_valid
    end
  end

  describe "duplicates" do
    it "rejects the same contact twice on one list" do
      contact = create(:contact, user:)
      create(:contact_list_membership, contact_list: list, contact:)

      duplicate = build(:contact_list_membership, contact_list: list, contact:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include("Contact #{described_class::DUPLICATE_MESSAGE}")
    end

    it "is enforced by a unique index as well as the validation" do
      contact = create(:contact, user:)
      create(:contact_list_membership, contact_list: list, contact:)

      duplicate = build(:contact_list_membership, contact_list: list, contact:)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows one contact on two different lists" do
      contact = create(:contact, user:)
      create(:contact_list_membership, contact_list: list, contact:)

      other = create(:contact_list, user:)
      expect(build(:contact_list_membership, contact_list: other, contact:)).to be_valid
    end
  end
end
