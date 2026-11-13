Rails.application.routes.draw do
  devise_for :users
  post "/graphql", to: "graphql#execute"
  options "/graphql", to: "graphql#execute"
  post "/webhooks/stripe", to: "stripe_webhooks#create"
  post "/webhooks/slack", to: "slack_webhooks#create"

  # Slack OAuth installation callback
  namespace :oauth do
    get "slack/callback", to: "slack#callback"
  end

  # Card preview routes (supports both external_id and custom slug)
  get "/p/card/:id/editable", to: "previews#card_editable", as: :editable_card_preview
  get "/p/card/:id/viewable", to: "previews#card_viewable", as: :viewable_card_preview

  # Invitation preview routes (supports both external_id and custom slug)
  get "/p/invitation/:id", to: "previews#invitation_view", as: :invitation_preview
end
