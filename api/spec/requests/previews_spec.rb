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
      expect(response.body).to include('Celebrate Bob')
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

  describe 'GET non-existent card' do
    it 'raises ActiveRecord::RecordNotFound for missing card' do
      get '/p/card/nonexistent/editable'
      expect(response).to have_http_status(:not_found)
    end
  end
end
