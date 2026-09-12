# typed: true

# One row per time a signed-in user lands on the 1-on-1 create flow (#30). The
# denominator of "creation completion rate" — CreateOneOnOneCard's own count is
# the numerator. Deliberately just a timestamped user reference, not a general
# product-event log: a reload of the page double-counts a start the same way a
# real second attempt would, which is an acceptable amount of noise for a
# funnel ratio and far simpler than de-duplicating sessions.
class OneOnOneFlowStart < ApplicationRecord
  belongs_to :user
end
