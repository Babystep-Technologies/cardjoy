# Final step of retiring the PostCard product (#244): the models, GraphQL surface and PostGrid
# integration are already gone, and this removes their data.
#
# DESTRUCTIVE AND IRREVERSIBLE. `postage_credits` is a money ledger and `post_card_mail_orders`
# records physical mail, so the migration refuses to run while either still holds something
# someone is owed or waiting on:
#
#   * a user with a positive postage balance (they paid for postage and have no way to spend it)
#   * an order that PostGrid has not finished with (pending/submitted/printing/processed)
#
# Refund the balances and let in-flight orders finish first. If the data is known to be disposable
# (a dev or staging database, or balances already refunded out of band), run with
# ALLOW_POSTCARD_DATA_DROP=1 to override the guard.
class DropPostCardTables < ActiveRecord::Migration[8.1]
  IN_FLIGHT_STATUSES = %w[pending submitted printing processed_for_delivery].freeze

  def up
    guard_against_losing_money_data unless ENV["ALLOW_POSTCARD_DATA_DROP"] == "1"

    # Photos were Active Storage attachments on PostCard; remove them with the rows that owned them.
    execute(<<~SQL.squish)
      DELETE FROM active_storage_attachments WHERE record_type = 'PostCard'
    SQL
    execute(<<~SQL.squish)
      DELETE FROM active_storage_blobs
      WHERE id NOT IN (SELECT blob_id FROM active_storage_attachments)
        AND id NOT IN (SELECT blob_id FROM active_storage_variant_records WHERE blob_id IS NOT NULL)
    SQL

    drop_table :post_card_mail_orders
    drop_table :post_cards
    drop_table :postage_credits

    # PostGrid address verification cache on contacts.
    remove_column :contacts, :address_verified_at
    remove_column :contacts, :address_verification_status
    remove_column :contacts, :address_zone
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "PostCard data was deleted and cannot be restored"
  end

  private

  def guard_against_losing_money_data
    owed = select_value(<<~SQL.squish).to_i
      SELECT count(*) FROM (
        SELECT user_id FROM postage_credits GROUP BY user_id HAVING SUM(amount_cents) > 0
      ) balances
    SQL
    in_flight = select_value(<<~SQL.squish).to_i
      SELECT count(*) FROM post_card_mail_orders
      WHERE status IN (#{IN_FLIGHT_STATUSES.map { |status| quote(status) }.join(', ')})
    SQL
    return if owed.zero? && in_flight.zero?

    raise <<~MESSAGE
      Refusing to drop the PostCard tables:
        #{owed} user(s) hold a positive postage balance
        #{in_flight} order(s) are still in flight
      Refund the balances and let orders finish, or set ALLOW_POSTCARD_DATA_DROP=1 to drop anyway.
    MESSAGE
  end
end
