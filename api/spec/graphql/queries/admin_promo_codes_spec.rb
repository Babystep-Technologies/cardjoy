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
      query AdminPromoCodes($page: Int, $perPage: Int, $search: String, $status: String, $sort: String, $direction: String) {
        adminPromoCodes(page: $page, perPage: $perPage, search: $search, status: $status, sort: $sort, direction: $direction) {
          promoCodes { code creditAmount usageLimit timesRedeemed disabledAt status user { email } }
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

  describe 'status' do
    let!(:active) { create(:promo_code, code: 'active') }
    let!(:expired) { create(:promo_code, :expired, code: 'expired') }
    let!(:disabled) { create(:promo_code, :disabled, code: 'disabled') }
    let!(:fully_redeemed) { create(:promo_code, :limit_reached, code: 'fullyredeemed') }

    def codes_for(status)
      run(variables: { status: status })
      JSON.parse(response.body)['data']['adminPromoCodes']['promoCodes'].map { |p| p['code'] }
    end

    it 'filters to each lifecycle state' do
      expect(codes_for('active')).to eq [ 'active' ]
      expect(codes_for('expired')).to eq [ 'expired' ]
      expect(codes_for('disabled')).to eq [ 'disabled' ]
      expect(codes_for('fully_redeemed')).to eq [ 'fullyredeemed' ]
    end

    it 'reports the derived status on each code, disabled winning over expired' do
      create(:promo_code, :expired, :disabled, code: 'both')

      run
      statuses = JSON.parse(response.body)['data']['adminPromoCodes']['promoCodes']
        .to_h { |p| [ p['code'], p['status'] ] }
      expect(statuses).to include('active' => 'active', 'expired' => 'expired',
        'disabled' => 'disabled', 'fullyredeemed' => 'fully_redeemed', 'both' => 'disabled')
    end

    it 'rejects an unknown status' do
      run(variables: { status: 'bogus' })
      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Invalid status: bogus'
    end
  end

  describe 'sort' do
    it 'orders by the requested column and direction' do
      create(:promo_code, code: 'b', credit_amount: 5)
      create(:promo_code, code: 'a', credit_amount: 20)

      run(variables: { sort: 'credit_amount', direction: 'asc' })
      asc = JSON.parse(response.body)['data']['adminPromoCodes']['promoCodes'].map { |p| p['code'] }
      run(variables: { sort: 'code', direction: 'desc' })
      desc = JSON.parse(response.body)['data']['adminPromoCodes']['promoCodes'].map { |p| p['code'] }

      expect(asc).to eq %w[b a]
      expect(desc).to eq %w[b a]
    end

    it 'rejects an unknown sort or direction' do
      run(variables: { sort: 'bogus' })
      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Invalid sort: bogus'
      run(variables: { direction: 'sideways' })
      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Invalid direction: sideways'
    end
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
