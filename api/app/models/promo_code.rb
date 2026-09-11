# typed: true

class PromoCode < ApplicationRecord
  belongs_to :user, optional: true
  has_many :promo_code_redemptions, dependent: :destroy

  before_validation :normalize_code

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :credit_amount, numericality: { only_integer: true, greater_than: 0 }
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }
  # Validation: user-specific promo codes can only be used once
  validates :usage_limit, inclusion: { in: [ 1 ] }, if: :user_specific?

  # The lifecycle states a code can be in, checked in this order so the newest
  # decision wins: a disabled code reads "disabled" even if it had also expired.
  # Mirrors the computed statuses AdminListable exposes for the product lists,
  # but a promo status is derived from three different columns rather than one
  # timestamp, so it lives here rather than in that concern.
  STATUSES = %w[disabled expired fully_redeemed active].freeze

  # Columns Queries::AdminPromoCodes may order by. Model-authored and only ever
  # reached through this hash, which is what makes the value safe to interpolate
  # into SQL — the same contract as AdminListable::admin_sorts.
  SORTS = {
    "code" => "promo_codes.code",
    "credit_amount" => "promo_codes.credit_amount",
    "times_redeemed" => "promo_codes.times_redeemed",
    "expires_at" => "promo_codes.expires_at",
    "created_at" => "promo_codes.created_at"
  }.freeze

  scope :disabled, -> { where.not(disabled_at: nil) }
  scope :expired, -> { where("promo_codes.expires_at < ?", Time.current) }
  scope :fully_redeemed, lambda {
    where.not(usage_limit: nil).where("promo_codes.times_redeemed >= promo_codes.usage_limit")
  }

  # Generates a unique, human-friendly code not already in use.
  def self.generate_unique_code
    loop do
      candidate = "cj-#{SecureRandom.alphanumeric(8).downcase}"
      return candidate unless exists?(code: candidate)
    end
  end

  # The admin promo list (#180): a `search` over the code and the assigned
  # user's email, a `status` narrowing to one lifecycle state, and a `sort`.
  # Returns `[rows, total]` — the shape AdminListable#paginated hands back — but
  # bespoke, because the statuses are computed and the search columns are the
  # code and an association's email, not a product's title/external_id.
  #
  # An unknown status, sort, or direction raises ArgumentError; the resolver
  # turns that into a GraphQL error so a stale link says what is wrong with it,
  # exactly as Queries::AdminCards does.
  def self.admin_list(page: 1, per_page: 20, search: nil, status: nil, sort: nil, direction: nil)
    per_page = AdminListable.clamp_per_page(per_page)
    page = [ page.to_i, 1 ].max

    scope = admin_search_scope(all, search)
    scope = admin_status_scope(scope, status)

    # Counted before the order and the preload, so the total costs one plain
    # aggregate — the same ordering AdminListable#paginated uses.
    total = scope.count

    rows = scope
      .order(admin_order(sort, direction))
      .offset((page - 1) * per_page)
      .limit(per_page)
      .preload(:user)

    [ rows, total ]
  end

  # --- Lifecycle, for Mutations::UpdatePromoCodeByAdmin (#180) ---

  # The label Types::PromoCodeType exposes and the admin dashboard badges. See
  # STATUSES for why the order of these checks matters.
  def status
    return "disabled" if disabled?
    return "expired" if expired?
    return "fully_redeemed" if fully_redeemed?

    "active"
  end

  def disabled?
    disabled_at.present?
  end

  def expired?
    expires_at.present? && expires_at.past?
  end

  def fully_redeemed?
    usage_limit.present? && times_redeemed.to_i >= usage_limit
  end

  def disable!
    update!(disabled_at: Time.current) unless disabled?
  end

  def enable!
    update!(disabled_at: nil) if disabled?
  end

  # Bring the expiry forward to now. A code with no `expires_at` gets one; a
  # code that already expired is left as it was.
  def expire!
    update!(expires_at: Time.current) unless expired?
  end

  # Matches AdminListable#admin_search_scope: the code plus the owner's email,
  # left-joined so the matching rows stay countable and pageable in one query.
  def self.admin_search_scope(scope, search)
    return scope if search.blank?

    term = "%#{sanitize_sql_like(search.to_s.strip)}%"
    scope.left_joins(:user).where("promo_codes.code ILIKE :term OR users.email ILIKE :term", term: term)
  end
  private_class_method :admin_search_scope

  def self.admin_status_scope(scope, status)
    return scope if status.blank?
    raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)

    case status
    when "disabled" then scope.disabled
    when "expired" then scope.expired
    when "fully_redeemed" then scope.fully_redeemed
    when "active"
      scope.where(disabled_at: nil)
        .where("promo_codes.expires_at IS NULL OR promo_codes.expires_at >= :now", now: Time.current)
        .where("promo_codes.usage_limit IS NULL OR promo_codes.times_redeemed < promo_codes.usage_limit")
    end
  end
  private_class_method :admin_status_scope

  # Ties break on id so a row can't land on two pages when a batch shares a
  # created_at, matching AdminListable#admin_order.
  def self.admin_order(sort, direction)
    sort = sort.presence || "created_at"
    direction = (direction.presence || "desc").to_s.downcase

    column = SORTS.fetch(sort) { raise ArgumentError, "Invalid sort: #{sort}" }
    unless AdminListable::SORT_DIRECTIONS.include?(direction)
      raise ArgumentError, "Invalid sort direction: #{direction}"
    end

    Arel.sql("#{column} #{direction.upcase}, promo_codes.id DESC")
  end
  private_class_method :admin_order

  private

  def normalize_code
    self.code = code&.downcase&.strip
  end

  def user_specific?
    user_id.present?
  end
end
