# typed: false

require 'rails_helper'
require 'jwt'

# The credits & promos list the admin dashboard manages from (#180): search,
# status, and sort over Queries::AdminPromoCodes.
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
      query AdminPromoCodes($page: Int, $perPage: Int, $search: String, $status: String, $sort: String, $direction: String) {
        adminPromoCodes(page: $page, perPage: $perPage, search: $search, status: $status, sort: $sort, direction: $direction) {
          promoCodes { id code creditAmount usageLimit timesRedeemed status user { email } }
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

  def data(variables: {}, headers: admin_headers)
    run(variables: variables, headers: headers)
    JSON.parse(response.body)['data']&.dig('adminPromoCodes')
  end

  it 'returns paginated promo codes newest first for an admin' do
    create(:promo_code, code: 'older')
    create(:promo_code, :user_specific, code: 'newer', user: user)

    result = data(variables: { page: 1, perPage: 20 })

    expect(result['totalCount']).to eq 2
    expect(result['promoCodes'].first['code']).to eq 'newer'
    expect(result['promoCodes'].first['user']['email']).to eq user.email
  end

  it 'rejects non-admins' do
    create(:promo_code)
    run(headers: user_headers)
    expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Not authorized'
  end

  describe 'search' do
    it 'matches the code' do
      match = create(:promo_code, code: 'summer-sale')
      create(:promo_code, code: 'other')

      result = data(variables: { search: 'summer' })

      expect(result['totalCount']).to eq 1
      expect(result['promoCodes'].first['id']).to eq match.id.to_s
    end

    it "matches the assigned user's email" do
      assignee = create(:user, email: 'dana@example.com')
      match = create(:promo_code, :user_specific, user: assignee)
      create(:promo_code)

      result = data(variables: { search: 'dana@' })

      expect(result['totalCount']).to eq 1
      expect(result['promoCodes'].first['id']).to eq match.id.to_s
    end
  end

  describe 'status' do
    it 'narrows to disabled codes' do
      disabled = create(:promo_code, :disabled)
      create(:promo_code)

      result = data(variables: { status: 'disabled' })

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ disabled.id.to_s ]
    end

    it 'narrows to expired codes' do
      expired = create(:promo_code, :expired)
      create(:promo_code)

      result = data(variables: { status: 'expired' })

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ expired.id.to_s ]
    end

    it 'narrows to fully redeemed codes' do
      redeemed = create(:promo_code, :limit_reached)
      create(:promo_code)

      result = data(variables: { status: 'fully_redeemed' })

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ redeemed.id.to_s ]
    end

    it 'narrows to active codes, excluding disabled, expired, and fully redeemed ones' do
      active = create(:promo_code)
      create(:promo_code, :disabled)
      create(:promo_code, :expired)
      create(:promo_code, :limit_reached)

      result = data(variables: { status: 'active' })

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ active.id.to_s ]
    end

    it "reports each code's computed status" do
      disabled = create(:promo_code, :disabled)

      result = data

      expect(result['promoCodes'].find { |row| row['id'] == disabled.id.to_s }['status']).to eq 'disabled'
    end

    it 'rejects an unknown status' do
      run(variables: { status: 'bogus' })

      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Invalid status: bogus'
    end
  end

  describe 'sort' do
    it 'sorts by credit amount' do
      low = create(:promo_code, credit_amount: 5)
      high = create(:promo_code, credit_amount: 50)

      result = data(variables: { sort: 'credit_amount', direction: 'asc' })

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ low.id.to_s, high.id.to_s ]
    end

    it 'defaults to created_at descending' do
      older = create(:promo_code, created_at: 2.days.ago)
      newer = create(:promo_code, created_at: 1.day.ago)

      result = data

      expect(result['promoCodes'].map { |row| row['id'] }).to eq [ newer.id.to_s, older.id.to_s ]
    end

    it 'rejects an unknown sort' do
      run(variables: { sort: 'bogus' })

      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Invalid sort: bogus'
    end
  end
end
