# typed: true

module Sources
  # Batch-load per-card mail order counts, so a dashboard listing N holiday
  # cards costs one grouped query rather than N (#153).
  #
  # Returns a summary for every id asked for, including cards with no orders at
  # all — a card that was never sent is the common case on this list, and it
  # needs a zeroed summary to render "not sent yet" rather than a nil the field
  # would have to be nullable for.
  class HolidayCardOrderSummaryByCardId < GraphQL::Dataloader::Source
    def fetch(card_ids)
      counts = HolidayCardMailOrder
        .where(holiday_card_id: card_ids)
        .group(:holiday_card_id, :status)
        .count

      # The most recent order per card, so the list can say *when* a card was
      # last sent without loading the orders themselves.
      last_ordered = HolidayCardMailOrder
        .where(holiday_card_id: card_ids)
        .group(:holiday_card_id)
        .maximum(:created_at)

      card_ids.map { |card_id| summarize(card_id, counts, last_ordered) }
    end

    private

    def summarize(card_id, counts, last_ordered)
      by_status = Hash.new(0)
      counts.each do |(id, status), count|
        by_status[status] += count if id == card_id
      end

      # `failed` and `cancelled` are grouped because they mean the same thing to
      # the person reading it: this piece will not arrive, and the money came
      # back. HolidayCardMailOrder::REFUNDABLE_STATUSES is the same pairing the
      # refund path uses, read from there rather than restated.
      failed = HolidayCardMailOrder::REFUNDABLE_STATUSES.sum { |status| by_status[status] }
      delivered = by_status[HolidayCardMailOrder::COMPLETED]
      total = by_status.values.sum

      {
        total:,
        failed:,
        delivered:,
        # Everything still moving. Derived rather than listed, so a status added
        # to STATUSES later is counted as in-flight instead of vanishing.
        in_flight: total - failed - delivered,
        last_ordered_at: last_ordered[card_id]
      }
    end
  end
end
