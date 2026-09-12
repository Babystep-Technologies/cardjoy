# typed: false

require 'rails_helper'
require 'jwt'

RSpec.describe Queries::AdminPromoCodes, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:admin_token) { JWT.encode({ admin_id: admin.id }, secret, 'HS256') }
  let(:user_token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }

  let(:admin_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{admin_token}" }
  end
  let(:user_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }
  end

  let(:query) do
    <<~GQL
      query AdminPromoCodes($page: Int, $perPage: Int, $search: String) {
        adminPromoCodes(page: $page, perPage: $perPage, search: $search) {
          promoCodes { code creditAmount usageLimit timesRedeemed user { email } }
          totalCount
          totalPages
          page
          perPage
        }
      }
    GQL
  end

  def run(variables: {}, headers: admin_headers)
    post '/graphql', params: { query: query, variables: variables }.to_json, headers: headers
  end

  it 'returns paginated promo codes newest first for an admin' do
    create(:promo_code, code: 'older')
    create(:promo_code, :user_specific, code: 'newer', user: user)

    run(variables: { page: 1, perPage: 20 })

    data = JSON.parse(response.body)['data']['adminPromoCodes']
    expect(data['totalCount']).to eq 2
    expect(data['promoCodes'].first['code']).to eq 'newer'
    expect(data['promoCodes'].first['user']['email']).to eq user.email
  end

  it 'rejects non-admins' do
    create(:promo_code)
    run(headers: user_headers)
    expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Not authorized'
  end

  describe 'search' do
    it 'matches the code' do
      create(:promo_code, code: 'welcome2026')
      create(:promo_code, code: 'summer2026')

      run(variables: { search: 'welcome' })

      data = JSON.parse(response.body)['data']['adminPromoCodes']
      expect(data['promoCodes'].map { |p| p['code'] }).to eq [ 'welcome2026' ]
    end

    it "matches the assigned user's email" do
      match = create(:promo_code, :user_specific, code: 'match', user: create(:user, email: 'target@example.com'))
      create(:promo_code, :user_specific, code: 'nomatch', user: create(:user, email: 'other@example.com'))

      run(variables: { search: 'target@example.com' })

      data = JSON.parse(response.body)['data']['adminPromoCodes']
      expect(data['promoCodes'].map { |p| p['code'] }).to eq [ match.code ]
    end

    it 'still finds a general code with no assigned user' do
      create(:promo_code, code: 'general2026', user_id: nil)

      run(variables: { search: 'general' })

      data = JSON.parse(response.body)['data']['adminPromoCodes']
      expect(data['promoCodes'].map { |p| p['code'] }).to eq [ 'general2026' ]
    end
  end
end
