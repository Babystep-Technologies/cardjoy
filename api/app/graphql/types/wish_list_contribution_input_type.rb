# typed: true
# frozen_string_literal: true

module Types
  class WishListContributionInputType < Types::BaseInputObject
    argument :kind, String, required: true
    argument :handle, String, required: true
    argument :label, String, required: false
    argument :suggested_amount, String, required: false
    argument :note, String, required: false
  end
end
