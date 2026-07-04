# typed: true
# frozen_string_literal: true

module Queries
  class CheckSlugAvailability < BaseQuery
    argument :slug, String, required: true
    argument :type, String, required: true # "card" or "invitation"
    argument :current_id, String, required: false # external_id of current item being edited

    type Boolean, null: false

    def resolve(slug:, type:, current_id: nil)
      return true if slug.blank?

      case type.downcase
      when "card"
        query = ::Card.where(slug: slug)
        query = query.where.not(external_id: current_id) if current_id.present?
        !query.exists?
      when "invitation"
        query = ::Invitation.where(slug: slug)
        query = query.where.not(external_id: current_id) if current_id.present?
        !query.exists?
      else
        false
      end
    end
  end
end
