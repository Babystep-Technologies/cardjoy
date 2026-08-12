# Preview all emails at http://localhost:3000/rails/mailers/card_mailer_mailer
#
# The two previews below are the visual counterpart to the branding specs
# (#123): side by side they show exactly what an organization's branding
# changes, and what it leaves alone.
class CardMailerPreview < ActionMailer::Preview
  # A card owned by a fully branded organization: its logo, accent color,
  # footer, and Reply-To.
  def collaborator_invite_branded
    CardMailer.collaborator_invite('invitee@example.com', card_for(branded_organization))
  end

  # The same email for a personal card — no organization, so CardJoy's own
  # branding throughout. This is the output pinned byte-for-byte by
  # spec/mailers/mailer_layout_spec.rb.
  def collaborator_invite_personal
    CardMailer.collaborator_invite('invitee@example.com', card_for(nil))
  end

  private

  def card_for(organization)
    Card.new(
      title: 'Congrats on 10 years, Dana!',
      recipients: [ 'Dana' ],
      kind: 'group',
      external_id: 'PREVIEW',
      organization: organization
    )
  end

  # Built in memory so the preview needs no seed data. The logo is stubbed onto
  # the instance because MailerBrand asks an ActiveStorage attachment whether it
  # exists, and an unsaved record has none — this is the one thing a preview
  # can't get for free.
  def branded_organization
    Organization.new(
      name: 'Acme Corp',
      slug: 'acme-corp',
      accent_color: '#ff0055',
      email_footer_text: '© 2026 Acme Corp — sent with CardJoy',
      email_reply_to: 'people@acme.example'
    ).tap do |organization|
      organization.define_singleton_method(:logo) { Struct.new(:attached?).new(true) }
      organization.define_singleton_method(:logo_url) do
        'https://placehold.co/320x120/ff0055/ffffff.png?text=Acme+Corp'
      end
    end
  end
end
