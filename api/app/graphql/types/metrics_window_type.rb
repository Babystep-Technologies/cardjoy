# typed: true

module Types
  # The windows Queries::AdminMetrics can be asked for (#183). A fixed enum
  # rather than a `days` integer — the old dailyMetrics(days:) accepted any
  # integer, including one that would zero-fill hundreds of years of rows;
  # this makes an unbounded window a type error instead of a runtime one.
  class MetricsWindowType < Types::BaseEnum
    value "THIRTY_DAYS", "The trailing 30 days, including today."
    value "NINETY_DAYS", "The trailing 90 days, including today."
    value "YEAR_TO_DATE", "From January 1st of the current year through today."
    value "ALL_TIME", "From the earliest recorded activity through today."
  end
end
