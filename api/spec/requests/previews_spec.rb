require 'rails_helper'

RSpec.describe 'Previews', type: :request do
  describe 'GET /p/card/:external_id/editable' do
    let!(:card) { create(:card, title: 'Happy Birthday!', external_id: 'ABCDEFG', recipients: [ 'Alice' ], occasion: 'Birthday') }

    it 'returns a successful response with editable URL' do
      get "/p/card/#{card.external_id}/editable"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('birthday')
      expect(response.body).to include('ABCDEFG')
      expect(response.body).to include('og:image')
      expect(response.body).to include('og:url')
    end
  end

  describe 'GET /p/card/:external_id/viewable' do
    let!(:card) { create(:card, title: 'Congratulations!', external_id: 'ABCDEFG', recipients: [ 'Bob' ], occasion: 'Graduation') }

    it 'returns a successful response with viewable URL' do
      get "/p/card/#{card.external_id}/viewable"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('A graduation card for Bob')
      expect(response.body).to include('ABCDEFG')
      expect(response.body).to include('og:image')
      expect(response.body).to include('og:url')
    end

    it 'redirects to an absolute frontend URL, not a bare path resolved against the API host' do
      allow(AppConfig).to receive(:frontend_url).and_return('https://cardjoy.app')

      get "/p/card/#{card.external_id}/viewable"

      expect(response.body).to include('url=https://cardjoy.app/card/ABCDEFG/viewable')
      expect(response.body).not_to include('url=/card/')
    end
  end

  describe 'viewable vs editable copy' do
    let!(:card) { create(:card, external_id: 'ABCDEFG', recipients: [ 'Alice' ], occasion: 'Birthday') }

    it 'pitches the editable link as a call to write a message' do
      get "/p/card/#{card.external_id}/editable"

      expect(og_title).to eq("Write a message to make Alice's birthday unforgettable 🎂")
      expect(og_description).to eq("Celebrate Alice's birthday with your message!")
    end

    it 'pitches the viewable link as an invitation to read the card' do
      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq('Alice has a birthday card waiting 🎂')
      expect(og_description).to eq('Open it to take a look.')
    end

    it 'never asks a viewer to write a message' do
      get "/p/card/#{card.external_id}/viewable"

      expect(response.body).not_to match(/write a message/i)
    end
  end

  describe 'viewable copy edge cases' do
    it 'reads sensibly for a card with no occasion' do
      card = create(:card, recipients: [ 'Alice' ], occasion: nil)

      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq('A card for Alice 💌')
    end

    it 'reads sensibly for a card with a blank occasion' do
      card = create(:card, recipients: [ 'Alice' ], occasion: '')

      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq('A card for Alice 💌')
    end

    it 'joins two recipients and agrees the verb' do
      card = create(:card, recipients: [ 'Alice', 'Bob' ], occasion: 'Birthday')

      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq('Alice & Bob have a birthday card waiting 🎂')
    end

    it 'joins three or more recipients' do
      card = create(:card, recipients: [ 'Alice', 'Bob', 'Carol' ], occasion: 'Farewell')

      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq('A farewell card for Alice, Bob & Carol 👋')
    end

    it 'falls back to naming the occasion for an unrecognised one' do
      card = create(:card, recipients: [ 'Alice' ], occasion: 'Work anniversary')

      get "/p/card/#{card.external_id}/viewable"

      expect(og_title).to eq("A card for Alice's Work anniversary ✨")
    end
  end

  describe 'viewable signature count' do
    let(:card) { create(:card, recipients: [ 'Alice' ], occasion: 'Birthday') }

    it 'omits the count when nobody has signed' do
      get "/p/card/#{card.external_id}/viewable"

      expect(og_description).to eq('Open it to take a look.')
    end

    it 'uses the singular for a single signature' do
      create(:message, card: card)

      get "/p/card/#{card.external_id}/viewable"

      expect(og_description).to eq("1 person signed it. Open it to read everyone's birthday wishes.")
    end

    it 'counts member and guest messages together' do
      create_list(:message, 2, card: card)
      create(:guest_message, card: card)

      get "/p/card/#{card.external_id}/viewable"

      expect(og_description).to eq("3 people signed it. Open it to read everyone's birthday wishes.")
    end
  end

  describe 'unfurl image metadata' do
    let!(:card) { create(:card, recipients: [ 'Alice' ], occasion: 'Birthday') }

    it 'names the site and describes the image' do
      get "/p/card/#{card.external_id}/viewable"

      expect(response.body).to include('<meta property="og:site_name" content="CardJoy" />')
      expect(response.body).to include('og:image:alt')
    end

    it 'declares the dimensions of the default image' do
      get "/p/card/#{card.external_id}/viewable"

      expect(response.body).to include('<meta property="og:image" content="https://cardjoy.app/og-image.png" />')
      expect(meta_property('og:image:width')).to eq('1224')
      expect(meta_property('og:image:height')).to eq('792')
      expect(meta_name('twitter:card')).to eq('summary_large_image')
    end

    it 'declares the dimensions of an attached cover image and keeps the large card when landscape' do
      attach_cover_image(card, width: 1600, height: 900)

      get "/p/card/#{card.external_id}/viewable"

      expect(meta_property('og:image:width')).to eq('1600')
      expect(meta_property('og:image:height')).to eq('900')
      expect(meta_name('twitter:card')).to eq('summary_large_image')
    end

    it 'drops to the small twitter card when the cover image is portrait' do
      attach_cover_image(card, width: 900, height: 1600)

      get "/p/card/#{card.external_id}/viewable"

      expect(meta_name('twitter:card')).to eq('summary')
    end
  end

  describe 'GET non-existent card' do
    it 'raises ActiveRecord::RecordNotFound for missing card' do
      get '/p/card/nonexistent/editable'
      expect(response).to have_http_status(:not_found)
    end
  end

  def og_title = meta_property('og:title')
  def og_description = meta_property('og:description')

  def meta_property(property)
    Nokogiri::HTML(response.body).at_css(%(meta[property="#{property}"]))&.[]('content')
  end

  def meta_name(name)
    Nokogiri::HTML(response.body).at_css(%(meta[name="#{name}"]))&.[]('content')
  end

  # Analysis normally runs in a background job; stub the metadata the view reads instead.
  def attach_cover_image(card, width:, height:)
    card.cover_image.attach(
      io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    card.cover_image.blob.update!(metadata: { 'width' => width, 'height' => height, 'analyzed' => true })
  end
end
