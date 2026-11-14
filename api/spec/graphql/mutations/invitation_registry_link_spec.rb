require 'rails_helper'

RSpec.describe "Linking an invitation to a registry", type: :request do
  let(:user) { create(:user) }
  let(:invitation) { create(:invitation, user: user) }
  let(:registry) { create(:wish_list, :standalone, user: user, visible: true) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:headers) { { 'Authorization' => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" } }

  def link(registry_external_id, as: headers)
    post '/graphql', params: { query: <<~GRAPHQL, variables: { id: invitation.external_id, rid: registry_external_id } }, headers: as
      mutation SetInvitationRegistry($id: String!, $rid: String) {
        setInvitationRegistry(input: { invitationExternalId: $id, registryExternalId: $rid }) {
          invitation { registry { externalId title } }
          errors
        }
      }
    GRAPHQL
    JSON.parse(response.body).dig('data', 'setInvitationRegistry')
  end

  it "links one of the owner's registries and exposes it on the invitation" do
    result = link(registry.external_id)

    expect(result['errors']).to be_empty
    expect(result.dig('invitation', 'registry', 'externalId')).to eq(registry.external_id)
    expect(invitation.reload.registry).to eq(registry)
  end

  it 'clears the link with a blank id' do
    invitation.update!(registry: registry)

    expect(link('')['errors']).to be_empty
    expect(invitation.reload.registry).to be_nil
  end

  it "refuses someone else's registry" do
    theirs = create(:wish_list, :standalone, visible: true)

    expect(link(theirs.external_id)['errors']).to eq([ 'Registry not found' ])
    expect(invitation.reload.registry).to be_nil
  end

  it "refuses an invitation's own wish list as a registry" do
    own = create(:wish_list, invitation: invitation, user: user)

    expect(link(own.external_id)['errors']).to eq([ 'Registry not found' ])
  end

  it "won't edit an invitation the caller can't edit" do
    stranger = { 'Authorization' => "Bearer #{JWT.encode({ user_id: create(:user).id }, secret, 'HS256')}" }

    expect(link(registry.external_id, as: stranger)['errors']).to eq([ 'Invitation not found' ])
  end

  it 'does not expose a registry that is not shared, and survives its deletion' do
    invitation.update!(registry: registry)
    registry.update!(visible: false)

    post '/graphql', params: { query: "query { invitation(id: \"#{invitation.external_id}\") { registry { externalId } } }" }, headers: headers
    expect(JSON.parse(response.body).dig('data', 'invitation', 'registry')).to be_nil

    registry.destroy!
    expect(invitation.reload.registry_id).to be_nil
  end
end
