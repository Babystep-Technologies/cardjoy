require "rails_helper"

RSpec.describe Mutations::CreateCoverStyle, type: :request do
  let(:admin) { create(:admin) }
  let(:token) do
    JWT.encode({ admin_id: admin.id }, Rails.application.credentials.dig(:jwt, :secret), 'HS256')
  end

  let(:headers) do
    {
      "Authorization" => "Bearer #{token}"
    }

    # Note: Content-Type is automatically set by Rack when using multipart + file param
  end

  let(:file) do
    fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg")
  end

  let(:query) do
    <<~GRAPHQL
      mutation CreateCoverStyle($input: CreateCoverStyleInput!) {
        createCoverStyle(input: $input) {
          style {
            id
            name
            kind
            value
            tags {
              name
            }
          }
          errors
        }
      }
    GRAPHQL
  end

  it "creates a cover style and attaches image via upload" do
    operations = {
      query: query,
      variables: {
        input: {
          tagNames: [ "birthday", "fun" ],
          file: nil
        }
      }
    }

    map = {
      "0" => [ "variables.input.file" ]
    }

    post "/graphql",
      params: {
        operations: operations.to_json,
        map: map.to_json,
        "0" => file
      },
      headers: headers,
      as: :multipart

    json = JSON.parse(response.body)
    data = json.dig("data", "createCoverStyle")

    expect(data["errors"]).to be_empty
    expect(data["style"]["name"]).to eq("test_image.jpg")
    expect(data["style"]["kind"]).to eq("cover")

    style = Style.find_by(name: "test_image.jpg")
    expect(style).to be_present
    expect(style.image).to be_attached
    expect(style.tags.map(&:name)).to include("birthday", "fun")
  end
end
