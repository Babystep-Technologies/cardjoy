# typed: false

require "rails_helper"

RSpec.describe RefreshWishListPricesJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:list) { create(:wish_list, :standalone, visible: true) }

  def item(**attrs)
    create(:wish_list_item, wish_list: list, url: "https://shop.example/p/1", price: "$20", **attrs)
  end

  def fetches(price)
    allow(WishListLinkPreview).to receive(:fetch).and_return(
      price.nil? ? nil : WishListLinkPreview::Result.new(title: "T", price: price)
    )
  end

  it "reads amounts across formats" do
    expect(described_class.amount("$1,019.99")).to eq(BigDecimal("1019.99"))
    expect(described_class.amount("19.99 EUR")).to eq(BigDecimal("19.99"))
    expect(described_class.amount("free")).to be_nil
  end

  it "updates a price that moved" do
    row = item
    fetches("$25")

    described_class.new.perform

    expect(row.reload.price).to eq("$25")
    expect(row.price_checked_at).to be_present
  end

  it "confirms an unchanged price without rewriting it, so it stops looking stale" do
    row = item
    row.update_columns(price_updated_at: 40.days.ago)
    fetches("20.00")

    described_class.new.perform

    expect(row.reload.price).to eq("$20")
    expect(row.price_stale?).to be(false)
  end

  it "leaves the price alone when the fetch fails or finds none, but records the attempt" do
    row = item
    fetches(nil)

    described_class.new.perform

    expect(row.reload.price).to eq("$20")
    expect(row.price_checked_at).to be_present
  end

  it "skips recently checked items, hidden registries and past events" do
    recent = item(price_checked_at: 1.day.ago)
    hidden = create(:wish_list_item, wish_list: create(:wish_list, :standalone, visible: false), url: "https://shop.example/h", price: "$1")
    past = create(:wish_list_item, wish_list: create(:wish_list, :standalone, visible: true, event_date: Date.current - 1), url: "https://shop.example/q", price: "$1")
    fetches("$99")

    described_class.new.perform

    expect([ recent, hidden, past ].map { |i| i.reload.price }).not_to include("$99")
  end

  it "fetches at most a few items per store in one run" do
    8.times { |i| create(:wish_list_item, wish_list: list, url: "https://shop.example/p/#{i}", price: "$1") }
    fetches("$2")

    described_class.new.perform

    expect(WishListLinkPreview).to have_received(:fetch).exactly(described_class::PER_HOST).times
  end
end
