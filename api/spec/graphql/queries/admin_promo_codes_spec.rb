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
      query AdminPromoCodes($page: Int, $perPage: Int) {
        adminPromoCodes(page: $page, perPage: $perPage) {
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
end
