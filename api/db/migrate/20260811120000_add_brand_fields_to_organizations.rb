class AddBrandFieldsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    # All three are nullable and stay nil for the vast majority of
    # organizations: nil means "use CardJoy's own branding", which is what every
    # row created before #123 gets. See MailerBrand for the fallbacks.
    add_column :organizations, :accent_color, :string
    add_column :organizations, :email_footer_text, :string
    add_column :organizations, :email_reply_to, :string
  end
end
