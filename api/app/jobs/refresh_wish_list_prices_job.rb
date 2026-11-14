# typed: true
# frozen_string_literal: true

# Daily cron job (config/initializers/good_job.rb), #246. Re-reads the price of registry items from
# their own links, so a guest isn't shown a price that has quietly moved. Runs in the background,
# never on a guest's page view, so a page load can't be used to make the server fetch URLs.
#
# Bounded on purpose: items are tried oldest-checked first, at most BATCH per run and PER_HOST from
# any one store, so a long registry doesn't hammer a retailer. Registries past their event or hidden
# are skipped, and so are stores known to block us (WishListLinkPreview::BLOCKING_HOSTS). A fetch
# that fails or finds no price changes nothing (the "price may have changed" marker then appears on
# its own after a month); a price that matches what's stored is simply confirmed, which keeps the
# marker away.
class RefreshWishListPricesJob < ApplicationJob
  queue_as :default

  RECHECK_AFTER = 7.days
  BATCH = 100
  PER_HOST = 5

  def perform
    candidates.each do |item|
      refresh(item)
    rescue StandardError => e
      Rails.logger.error "RefreshWishListPricesJob: failed on item #{item.id}: #{e.message}"
    end
  end

  # The number in a price string, so "$19.99", "19.99" and "1,019.99 EUR" compare by amount.
  def self.amount(price)
    digits = price.to_s[/\d[\d,]*(?:\.\d+)?/]
    digits && BigDecimal(digits.delete(","))
  end

  private

  def candidates
    due = WishListItem.joins(:wish_list)
      .where.not(url: [ nil, "" ])
      .where(wish_lists: { visible: true })
      .where("wish_lists.event_date IS NULL OR wish_lists.event_date >= ?", Date.current)
      .where("wish_list_items.price_checked_at IS NULL OR wish_list_items.price_checked_at < ?", RECHECK_AFTER.ago)
      .order(Arel.sql("wish_list_items.price_checked_at ASC NULLS FIRST"))
      .limit(BATCH * 3)

    per_host = Hash.new(0)
    due.select do |item|
      host = host_of(item.url)
      next false if host.nil? || WishListLinkPreview.blocks_previews?(item.url.to_s) || per_host[host] >= PER_HOST

      per_host[host] += 1
      true
    end.first(BATCH)
  end

  def host_of(url)
    URI.parse(url.to_s).host
  rescue URI::InvalidURIError
    nil
  end

  def refresh(item)
    fetched = WishListLinkPreview.fetch(item.url.to_s)&.price
    item.update_columns(price_checked_at: Time.current)
    return if fetched.blank?

    if self.class.amount(item.price) == self.class.amount(fetched)
      # Still what the owner entered: confirmed, so it is as fresh as the check.
      item.update_columns(price_updated_at: Time.current)
    else
      item.update!(price: fetched)
    end
  end
end
