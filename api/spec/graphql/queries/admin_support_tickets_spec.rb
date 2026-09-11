# typed: false

require "rails_helper"
require "jwt"

RSpec.describe "Admin support tickets", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:other_owner) { create(:user, name: "Sam Guest", email: "sam@example.com") }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def exec(variables: {}, token: admin_token)
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def subjects(variables)
    exec(variables: variables).dig("data", "adminSupportTickets", "supportTickets").map { |t| t["subject"] }
  end

  let(:query) do
    <<~GRAPHQL
      query AdminSupportTickets(
        $page: Int, $perPage: Int, $search: String, $status: String, $category: String,
        $assignedAdminId: ID, $sort: String
      ) {
        adminSupportTickets(
          page: $page, perPage: $perPage, search: $search, status: $status, category: $category,
          assignedAdminId: $assignedAdminId, sort: $sort
        ) {
          supportTickets {
            externalId
            subject
            status
            category
            customer { name email }
            assignedAdmin { id }
          }
          totalCount
          page
          perPage
          totalPages
        }
      }
    GRAPHQL
  end

  describe "authorization" do
    it "rejects a customer JWT" do
      create(:support_ticket, user: owner)

      body = exec(token: user_token)

      expect(body["errors"].first["message"]).to eq "Not authorized"
      expect(body.dig("data", "adminSupportTickets")).to be_nil
    end

    it "rejects an unauthenticated request" do
      exec(token: nil)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "default ordering" do
    it "surfaces the oldest open ticket first, ahead of everything else" do
      newer_open = create(:support_ticket, user: owner, subject: "Newer open",
        last_customer_reply_at: 1.hour.ago)
      older_open = create(:support_ticket, user: owner, subject: "Older open",
        last_customer_reply_at: 1.day.ago)
      create(:support_ticket, :pending, user: owner, subject: "Long-waiting pending",
        last_customer_reply_at: 1.week.ago)

      expect(subjects({})).to eq [ older_open.subject, newer_open.subject, "Long-waiting pending" ]
    end
  end

  describe "search" do
    before do
      create(:support_ticket, user: owner, subject: "Billing question")
      create(:support_ticket, user: other_owner, subject: "Feature idea")
    end

    it "matches the subject" do
      expect(subjects(search: "billing")).to eq [ "Billing question" ]
    end

    it "matches a message body" do
      ticket = ::SupportTicket.find_by(subject: "Feature idea")
      create(:support_ticket_message, support_ticket: ticket, body: "Please add dark mode")

      expect(subjects(search: "dark mode")).to eq [ "Feature idea" ]
    end

    it "matches the customer's email" do
      expect(subjects(search: "dana@example.com")).to eq [ "Billing question" ]
    end

    it "matches the customer's name" do
      expect(subjects(search: "Sam")).to eq [ "Feature idea" ]
    end

    it "does not duplicate a ticket whose thread has multiple matching messages" do
      ticket = ::SupportTicket.find_by(subject: "Billing question")
      create_list(:support_ticket_message, 2, support_ticket: ticket, body: "same word appears twice")

      expect(subjects(search: "same word")).to eq [ "Billing question" ]
    end
  end

  describe "filters" do
    let!(:open_ticket) { create(:support_ticket, user: owner, subject: "Open one", category: "Others") }
    let!(:pending_ticket) do
      create(:support_ticket, :pending, user: owner, subject: "Pending one", category: "Account question")
    end

    it "narrows to a status" do
      expect(subjects(status: "pending")).to eq [ "Pending one" ]
    end

    it "narrows to a category" do
      expect(subjects(category: "Account question")).to eq [ "Pending one" ]
    end

    it "narrows to one assignee" do
      other_admin = create(:admin)
      open_ticket.assign_to!(admin: admin)
      pending_ticket.assign_to!(admin: other_admin)

      expect(subjects(assignedAdminId: admin.id)).to eq [ "Open one" ]
    end

    it "rejects an unknown status rather than ignoring it" do
      body = exec(variables: { status: "sideways" })

      expect(body["errors"].first["message"]).to eq "Invalid status: sideways"
    end

    it "rejects an unknown sort" do
      body = exec(variables: { sort: "'; DROP TABLE support_tickets; --" })

      expect(body["errors"].first["message"]).to start_with "Invalid sort:"
      expect(::SupportTicket.count).to eq 2
    end
  end

  describe "pagination" do
    it "reports totalCount and clamps perPage" do
      create_list(:support_ticket, 3, user: owner)

      data = exec(variables: { perPage: 9999 }).dig("data", "adminSupportTickets")

      expect(data["totalCount"]).to eq 3
      expect(data["perPage"]).to eq AdminListable::MAX_PER_PAGE
    end
  end

  # The list has never selected the customer, so adding it would have cost a
  # query per row without an explicit preload.
  it "costs a fixed number of queries however many tickets are listed, including their customers" do
    create_list(:support_ticket, 5, user: owner)

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
      queries << payload[:sql] if payload[:sql].match?(/FROM "(support_tickets|users|admins)"/)
    end
    exec(variables: { perPage: 25 })
    ActiveSupport::Notifications.unsubscribe(subscriber)

    # The count, the page, and one preload each for user, assigned_admin, and
    # status_updated_by_admin.
    expect(queries.size).to eq 5
  end
end
