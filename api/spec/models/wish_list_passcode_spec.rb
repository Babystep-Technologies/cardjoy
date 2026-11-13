# typed: false

require "rails_helper"

RSpec.describe WishList, "passcode (#247)" do
  let(:list) { create(:wish_list, :standalone) }

  it "stores only a digest and matches the right passcode" do
    list.update!(passcode: "sunflower")

    expect(list.passcode_digest).not_to include("sunflower")
    expect(list).to be_passcode_protected
    expect(list.passcode_matches?("sunflower")).to be(true)
    expect(list.passcode_matches?(" sunflower ")).to be(true)
    expect(list.passcode_matches?("tulip")).to be(false)
    expect(list.passcode_matches?(nil)).to be(false)
  end

  it "salts, so equal passcodes get different digests" do
    other = create(:wish_list, :standalone)
    list.update!(passcode: "sunflower")
    other.update!(passcode: "sunflower")

    expect(list.passcode_digest).not_to eq(other.passcode_digest)
  end

  it "rejects a too-short passcode and keeps the old one" do
    list.update!(passcode: "sunflower")

    expect(list.update(passcode: "abc")).to be(false)
    expect(list.errors[:passcode].first).to include("at least 4")
    expect(list.reload.passcode_matches?("sunflower")).to be(true)
  end

  it "clears with a blank passcode" do
    list.update!(passcode: "sunflower")
    list.update!(passcode: "")

    expect(list).not_to be_passcode_protected
  end

  it "opens to the owner and to anyone when unprotected, otherwise needs the passcode" do
    stranger = create(:user)
    expect(list.open_to?(nil, nil)).to be(true)

    list.update!(passcode: "sunflower")
    expect(list.open_to?(nil, nil)).to be(false)
    expect(list.open_to?(stranger, "nope")).to be(false)
    expect(list.open_to?(stranger, "sunflower")).to be(true)
    expect(list.open_to?(list.user, nil)).to be(true)
  end

  it "keeps protected registries out of occasion-reminder matching" do
    list.update!(passcode: "sunflower")

    expect(described_class.open_to_guests).not_to include(list)
  end
end
