require 'rails_helper'

RSpec.describe "Linking a card to a registry", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }
  let(:card) { create(:card, user: user) }
  let(:registry) { create(:wish_list, user: user, invitation: nil, visible: true) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:headers) { { 'Authorization' => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" } }

  def update_card(registry_external_id)
    post '/graphql', params: { query: <<~GRAPHQL, variables: { cardId: card.external_id, rid: registry_external_id } }, headers: headers
      mutation UpdateCard($cardId: ID!, $rid: String) {
        updateCard(input: { cardId: $cardId, registryExternalId: $rid }) { success errors }
      }
    GRAPHQL
    JSON.parse(response.body).dig('data', 'updateCard')
  end

  def card_registry
    post '/graphql', params: { query: <<~GRAPHQL, variables: { id: card.external_id } }, headers: headers
      query($id: ID!) { card(cardId: $id) { registry { externalId title ownerFirstName } } }
    GRAPHQL
    JSON.parse(response.body).dig('data', 'card', 'registry')
  end

  it 'links one of the owner\'s registries and exposes it on the card' do
    expect(update_card(registry.external_id)['success']).to be(true)
    expect(card.reload.wish_list).to eq(registry)
    expect(card_registry).to include('externalId' => registry.external_id, 'title' => registry.title)
  end

  it 'clears the link with a blank id' do
    card.update!(wish_list: registry)
    expect(update_card('')['success']).to be(true)
    expect(card.reload.wish_list).to be_nil
  end

  it 'refuses someone else\'s registry' do
    theirs = create(:wish_list, user: other, invitation: nil, visible: true)
    result = update_card(theirs.external_id)
    expect(result['success']).to be(false)
    expect(card.reload.wish_list).to be_nil
  end

  it 'does not expose a registry that is not shared' do
    registry.update!(visible: false)
    card.update!(wish_list: registry)
    expect(card_registry).to be_nil
  end

  it 'hides the title of a passcode-protected registry' do
    registry.update!(passcode: 'sunflower')
    card.update!(wish_list: registry)

    expect(card_registry['title']).to eq('A private registry')
  end

  it 'leaves the card intact when the registry is deleted' do
    card.update!(wish_list: registry)
    registry.destroy!
    expect(card.reload.wish_list_id).to be_nil
  end
end
