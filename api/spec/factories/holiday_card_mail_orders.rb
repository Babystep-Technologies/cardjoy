FactoryBot.define do
  factory :holiday_card_mail_order do
    transient do
      # The contact the snapshot is taken from. Built mailable by default so an
      # order looks like one the send flow would have produced.
      recipient { association :contact, :mailable, user: }
    end

    user { association :user }
    holiday_card { association :holiday_card, user: }
    contact { recipient }
    recipient_snapshot { HolidayCardMailOrder.snapshot_for(recipient) }

    size { "6x4" }
    mailing_class { MailPricing::MAILING_CLASS_FIRST_CLASS }
    zone { PostGrid::AddressVerification::ZONE_US_DOMESTIC }
    rate_card_version { MailPricing::CURRENT_RATE_CARD_VERSION }
    # The real 6x4 domestic numbers, so a spec asserting on a refund amount is
    # asserting on something the rate card would actually have produced.
    base_cents { 86 }
    charged_cents { 112 }

    sequence(:idempotency_key) { |n| "spec-idempotency-key-#{n}" }
    status { HolidayCardMailOrder::PENDING }

    # Charged, submitted, and accepted — the state a successful job leaves
    # behind, for specs about what happens *after* submission.
    trait :submitted do
      status { HolidayCardMailOrder::SUBMITTED }
      postgrid_id { "postcard_spec1fakepostcardid" }
      submitted_at { Time.current }
    end

    trait :failed do
      status { HolidayCardMailOrder::FAILED }
      failure_reason { "Our print partner couldn't accept this card." }
    end
  end
end
