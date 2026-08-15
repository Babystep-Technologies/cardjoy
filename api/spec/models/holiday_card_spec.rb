require "rails_helper"

RSpec.describe HolidayCard, type: :model do
  def attach_photo(card)
    card.photos.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    card.photos.blobs.last
  end

  # A minimal valid design document pointing at `blob`.
  def design_config_for(blob, overrides = {})
    {
      "version" => 1,
      "front" => {
        "photos" => { "photo_1" => { "blob_id" => blob.id, "pan_x" => 0.1, "pan_y" => -0.05, "zoom" => 1.2 } },
        "texts" => { "greeting" => { "content" => "Happy Holidays", "font" => "playfair", "size" => "lg", "color" => "#8B0000" } },
        "stickers" => [ { "sticker_id" => "snowflake_gold", "region" => "corner_tl" } ]
      },
      "back" => { "photos" => {}, "texts" => {}, "stickers" => [] }
    }.deep_merge(overrides)
  end

  describe "external_id" do
    it "generates seven uppercase letters on create" do
      card = create(:holiday_card)
      expect(card.external_id).to match(/\A[A-Z]{7}\z/)
    end

    it "does not overwrite one that was supplied" do
      expect(create(:holiday_card, external_id: "ABCDEFG").external_id).to eq("ABCDEFG")
    end

    it "is unique" do
      create(:holiday_card, external_id: "ABCDEFG")
      duplicate = build(:holiday_card, external_id: "ABCDEFG")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).to include("has already been taken")
    end
  end

  describe "attributes" do
    it "defaults size to 6x4" do
      expect(HolidayCard.new.size).to eq("6x4")
    end

    it "rejects a size outside VALID_SIZES" do
      expect(build(:holiday_card, size: "8x10")).not_to be_valid
    end

    it "requires a template_id" do
      expect(build(:holiday_card, template_id: nil)).not_to be_valid
    end
  end

  describe "soft delete" do
    it "hides a deleted card from the default scope" do
      card = create(:holiday_card)
      card.delete!

      expect(HolidayCard.where(id: card.id)).to be_empty
      expect(HolidayCard.unscoped.where(id: card.id)).to be_present
      expect(card.deleted).to be(true)
    end

    it "brings a card back with restore!" do
      card = create(:holiday_card)
      card.delete!
      card.restore!

      expect(HolidayCard.where(id: card.id)).to be_present
    end
  end

  describe "design_config validation" do
    let(:card) { create(:holiday_card) }
    let(:blob) { attach_photo(card) }

    it "accepts an empty document — a fresh card has no content yet" do
      expect(build(:holiday_card, design_config: {})).to be_valid
    end

    it "accepts a fully populated document" do
      card.design_config = design_config_for(blob)
      expect(card).to be_valid
    end

    it "rejects an unknown version" do
      card.design_config = design_config_for(blob, "version" => 99)

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include("has an unknown version")
    end

    it "rejects a missing version" do
      card.design_config = design_config_for(blob).except("version")

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include("has an unknown version")
    end

    it "rejects an unknown panel key" do
      card.design_config = design_config_for(blob).merge("inside" => { "photos" => {} })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include("has an unknown panel inside")
    end

    it "rejects a font outside VALID_FONTS" do
      card.design_config = design_config_for(blob, "front" => { "texts" => { "greeting" => { "font" => "comic_sans" } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/invalid font/)
    end

    it "rejects a malformed color" do
      card.design_config = design_config_for(blob, "front" => { "texts" => { "greeting" => { "color" => "red" } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/invalid color/)
    end

    it "rejects a three-digit hex color — the print renderer only handles #rrggbb" do
      card.design_config = design_config_for(blob, "front" => { "texts" => { "greeting" => { "color" => "#f00" } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/invalid color/)
    end

    it "rejects an over-length text content" do
      long = "a" * (described_class::TEXT_CONTENT_MAX_LENGTH + 1)
      card.design_config = design_config_for(blob, "front" => { "texts" => { "greeting" => { "content" => long } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/longer than #{described_class::TEXT_CONTENT_MAX_LENGTH} characters/)
    end

    it "accepts text content exactly at the cap" do
      at_cap = "a" * described_class::TEXT_CONTENT_MAX_LENGTH
      card.design_config = design_config_for(blob, "front" => { "texts" => { "greeting" => { "content" => at_cap } } })

      expect(card).to be_valid
    end

    it "rejects an out-of-range zoom" do
      card.design_config = design_config_for(blob, "front" => { "photos" => { "photo_1" => { "zoom" => 42 } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/zoom outside/)
    end

    it "rejects a zoom below the minimum" do
      card.design_config = design_config_for(blob, "front" => { "photos" => { "photo_1" => { "zoom" => 0.1 } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/zoom outside/)
    end

    it "rejects a non-numeric pan" do
      card.design_config = design_config_for(blob, "front" => { "photos" => { "photo_1" => { "pan_x" => "left" } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/non-numeric pan_x/)
    end

    it "rejects a blob_id belonging to another user's card" do
      other_card = create(:holiday_card)
      other_blob = attach_photo(other_card)

      card.design_config = design_config_for(blob, "front" => { "photos" => { "photo_1" => { "blob_id" => other_blob.id } } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/not attached to this card/)
    end

    it "rejects a photo slot with no blob_id at all" do
      card.design_config = { "version" => 1, "front" => { "photos" => { "photo_1" => { "zoom" => 1.0 } } } }

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/not attached to this card/)
    end

    it "rejects a document that is not an object" do
      card.design_config = [ 1, 2, 3 ]

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include("must be an object")
    end

    it "rejects stickers that are not a list" do
      card.design_config = design_config_for(blob).deep_merge("front" => { "stickers" => { "a" => 1 } })

      expect(card).not_to be_valid
      expect(card.errors[:design_config]).to include(/stickers in panel front must be a list/)
    end

    it "never raises on a malformed document" do
      card.design_config = { "version" => 1, "front" => "nope" }

      expect { card.valid? }.not_to raise_error
      expect(card.errors[:design_config]).to include("panel front must be an object")
    end

    it "accepts template and sticker ids it has never seen — the catalogue owns those" do
      card.design_config = design_config_for(blob).deep_merge(
        "front" => { "stickers" => [ { "sticker_id" => "a_sticker_added_next_week", "region" => "somewhere_new" } ] }
      )
      card.template_id = "a_template_added_next_week"

      expect(card).to be_valid
    end
  end
end
