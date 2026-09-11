# typed: false

require "rails_helper"

RSpec.describe MetricsWindowRange do
  around do |example|
    travel_to(Time.utc(2026, 6, 15, 12, 0, 0)) { example.run }
  end

  it "covers the trailing 30 days for THIRTY_DAYS, including today" do
    range = described_class.new("THIRTY_DAYS")

    expect(range.start_date).to eq Date.new(2026, 5, 17)
    expect(range.end_date).to eq Date.new(2026, 6, 15)
  end

  it "covers the trailing 90 days for NINETY_DAYS" do
    range = described_class.new("NINETY_DAYS")

    expect(range.start_date).to eq Date.new(2026, 3, 18)
  end

  it "starts on January 1st for YEAR_TO_DATE" do
    range = described_class.new("YEAR_TO_DATE")

    expect(range.start_date).to eq Date.new(2026, 1, 1)
  end

  it "starts on the same day it ends when YEAR_TO_DATE is asked for on January 1st" do
    travel_to(Time.utc(2027, 1, 1, 0, 30, 0)) do
      range = described_class.new("YEAR_TO_DATE")

      expect(range.start_date).to eq range.end_date
    end
  end

  it "starts at the earliest tracked row for ALL_TIME" do
    create(:invitation, created_at: Time.utc(2025, 9, 1))

    range = described_class.new("ALL_TIME")

    expect(range.start_date).to eq Date.new(2025, 9, 1)
  end

  it "falls back to today for ALL_TIME when nothing has been created yet" do
    range = described_class.new("ALL_TIME")

    expect(range.start_date).to eq Date.current
  end

  it "looks back 6 extra days for the DAU rolling average" do
    range = described_class.new("THIRTY_DAYS")

    expect(range.dau_start_date).to eq range.start_date - 6
  end

  it "widens created_at bounds to the full first and last day" do
    range = described_class.new("THIRTY_DAYS")

    expect(range.sql_range.first).to eq Date.new(2026, 5, 17).beginning_of_day
    expect(range.sql_range.last).to eq Date.new(2026, 6, 15).end_of_day
  end

  it "rejects an unknown window" do
    expect { described_class.new("LAST_WEEK") }.to raise_error(ArgumentError, /Invalid window/)
  end
end
