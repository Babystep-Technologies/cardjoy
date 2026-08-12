require 'rails_helper'

# The safety net for organization branding (#123). Everything the branded layout
# does is a refactor of hardcoded literals into `@brand` readers, and the
# property that has to survive it is this: a *personal* send — one with no
# organization — renders exactly the bytes it rendered before organizations
# existed.
#
# The fixture was recorded from the pre-#123 layout. Regenerate it only when a
# layout change is intended, and read the resulting diff as what it is: a change
# to every customer-facing email CardJoy sends.
#
#   docker compose exec -e RECORD_MAILER_FIXTURE=1 api \
#     bundle exec rspec spec/mailers/mailer_layout_spec.rb
#
RSpec.describe 'mailer layout', type: :mailer do
  let(:fixture_path) { Rails.root.join('spec/fixtures/mailers/personal_collaborator_invite.html') }

  let(:frontend_url) { 'https://example.com' }
  let(:logo_url) { 'https://cdn.example.com/logo.gif' }
  let(:card) { create(:card, title: 'Test Card', external_id: 'ABCDEFG') }

  # The year is frozen so the footer's copyright doesn't invalidate the fixture
  # on New Year's Day; the logo URL is set because it is nil in the test
  # environment, which would skip the logo block the fixture exists to pin.
  around do |example|
    original_logo = Rails.application.config.x.app_logo_for_email
    Rails.application.config.x.app_logo_for_email = logo_url
    travel_to(Time.utc(2026, 6, 1, 12, 0, 0)) { example.run }
    Rails.application.config.x.app_logo_for_email = original_logo
  end

  before do
    # `and_call_original` first: lazily-loaded Rails internals (storage.yml)
    # dig into credentials too, and a bare `with` stub would reject them.
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
    stub_request(:head, logo_url)
  end

  it 'renders a personal send byte-identically to the pre-organizations layout' do
    rendered = CardMailer.collaborator_invite('test@example.com', card).body.decoded

    if ENV['RECORD_MAILER_FIXTURE']
      FileUtils.mkdir_p(File.dirname(fixture_path))
      File.write(fixture_path, rendered)
    end

    expect(rendered).to eq(File.read(fixture_path))
  end
end
