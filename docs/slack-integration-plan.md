# Slack Integration Plan

Build a Slack app that lets any workspace member type `/cardjoy create for Mike`, which creates a Cardjoy card owned by that user and responds with a shareable link.

---

## Architecture

```
[Slack Workspace] ──install via OAuth──▶ /oauth/slack/callback (Rails)
                                          stores workspace token in slack_installations

[User types /cardjoy create for Mike]
        │
        ▼
POST /webhooks/slack (Rails)
  ├─ verify Slack signature
  ├─ look up slack_user_connections for the Slack user_id
  │   └─ not found? → return ephemeral "Connect your account: <link>"
  ├─ create Card owned by linked Cardjoy user
  └─ respond with card URL

[First-time user clicks connect link]
  ▶ https://app.cardjoy.com/connect-slack?state=<signed_token>
  ▶ logs in if needed
  ▶ React page calls ConnectSlackAccount GraphQL mutation
  ▶ stores slack_user_id → cardjoy user_id mapping
```

---

## Checklist

### Step 1: Slack App Setup (external — api.slack.com) ⚠️ Manual
- [ ] Create new Slack App → "From scratch"
- [ ] **OAuth & Permissions** → Add Bot Token Scope: `commands`
- [ ] **Slash Commands** → Create `/cardjoy`, Request URL: `https://<api-domain>/webhooks/slack`
- [ ] **OAuth & Permissions** → Set Redirect URL: `https://<api-domain>/oauth/slack/callback`
- [ ] **Event Subscriptions** → Enable Events API, subscribe to `app_uninstalled` and `tokens_revoked` (for marketplace / Level 2)
- [ ] **Manage Distribution** → Enable public distribution
- [ ] Copy Client ID, Client Secret, Signing Secret

### Step 2: Rails Credentials ⚠️ Manual
- [ ] Add to Rails credentials (`docker compose exec api rails credentials:edit`):
  ```yaml
  slack:
    client_id: "..."
    client_secret: "..."
    signing_secret: "..."
  ```

### Step 3: Database Migrations ✅
- [x] Create `slack_installations` table (`api/db/migrate/20260327000001_create_slack_installations.rb`)
- [x] Create `slack_user_connections` table (`api/db/migrate/20260327000002_create_slack_user_connections.rb`)
- [ ] Run migrations: `docker compose exec api rails db:migrate`

### Step 4: Models ✅
- [x] `api/app/models/slack_installation.rb`
- [x] `api/app/models/slack_user_connection.rb`

### Step 5: Routes ✅
- [x] `api/config/routes.rb` — added `/webhooks/slack` and `/oauth/slack/callback`

### Step 6: OAuth Callback Controller ✅
- [x] `api/app/controllers/oauth/slack_controller.rb`

### Step 7: Slack Webhook Controller ✅
- [x] `api/app/controllers/slack_webhooks_controller.rb`
  - Slack signature verification
  - Slash command handler (parse recipient, look up user, create card)
  - `app_uninstalled` event handler
  - `tokens_revoked` event handler

### Step 8: ConnectSlackAccount GraphQL Mutation ✅
- [x] `api/app/graphql/mutations/connect_slack_account.rb`
- [x] Registered in `api/app/graphql/types/mutation_type.rb`

### Step 9: Frontend — Connect Slack Page ✅
- [x] `web/src/pages/ConnectSlack.tsx`
- [x] `/connect-slack` route added in `web/src/App.tsx`

### Step 10: "Add to Slack" Button ✅
- [x] `VITE_SLACK_CLIENT_ID` and `VITE_API_URL` added to `web/.env.development`
- [x] "Add to Slack" button added to `web/src/pages/Profile.tsx`
- [ ] Fill in `VITE_SLACK_CLIENT_ID` value in `.env.development` (and production env) once Slack app is created

---

## Verification

- [ ] Run migrations: `docker compose exec api rails db:migrate`
- [ ] Click "Add to Slack" on profile page → OAuth completes → workspace stored in `slack_installations`
- [ ] Run `/cardjoy create for Mike` (first time) → receive ephemeral "connect your account" message
- [ ] Click connect link → log in to Cardjoy → connection stored in `slack_user_connections`
- [ ] Run `/cardjoy create for Mike` again → card created, link returned in Slack channel
- [ ] Open card link → shows "Card for Mike" owned by your Cardjoy account
- [ ] Card appears in Cardjoy dashboard
- [ ] Uninstalling app from Slack → `slack_installations` + `slack_user_connections` cleaned up

---

## Slack App Directory (Level 2) — Additional Requirements

These are non-code requirements needed to submit for marketplace review:

- [ ] Privacy policy URL (point to existing cardjoy.com/privacy)
- [ ] Terms of service URL (point to existing cardjoy.com/terms)
- [ ] App icon: 512×512 PNG and 1024×1024 PNG
- [ ] Short description (≤150 chars)
- [ ] Long description
- [ ] Support URL or email
- [ ] At least one screenshot
- [ ] App category selected
- [ ] Submit via **Manage Distribution → Submit to App Directory**

> The event handling for `app_uninstalled` and `tokens_revoked` (Step 7) is the only *code* requirement specific to the App Directory review.

---

## Key Files

| File | Action |
|------|--------|
| `api/db/migrate/*_create_slack_installations.rb` | New |
| `api/db/migrate/*_create_slack_user_connections.rb` | New |
| `api/app/models/slack_installation.rb` | New |
| `api/app/models/slack_user_connection.rb` | New |
| `api/config/routes.rb` | Modify |
| `api/app/controllers/oauth/slack_controller.rb` | New |
| `api/app/controllers/slack_webhooks_controller.rb` | New |
| `api/app/graphql/mutations/connect_slack_account.rb` | New |
| `api/app/graphql/mutations/mutation_type.rb` | Modify |
| `web/src/pages/ConnectSlack.tsx` | New |
| `web/src/App.tsx` (router file) | Modify |
| `web/.env` / `web/.env.production` | Modify |
