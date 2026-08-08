# typed: true

module Queries
  # The signed-in user — who am I, and which organization am I acting in.
  #
  # Deliberately takes no arguments: it resolves from context[:current_user]
  # only, mirroring Queries::MyContacts. (Queries::UserCards takes a user_id;
  # that shape is wrong here, since the whole point is that the server, not the
  # client, decides who the caller is.)
  #
  # Active organization lives here rather than in the JWT so a switch takes
  # effect immediately and losing a membership is reflected on the next request.
  class Viewer < BaseQuery
    type Types::UserType, null: true

    def resolve
      context[:current_user]
    end
  end
end
