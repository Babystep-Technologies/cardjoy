# Development guide: how to build a feature

This is the shared reference for **humans, Claude skills, and the GitHub Action**. It shows the
conventions CardJoy follows so a change fits the codebase and passes CI. For the big-picture map, see
[ARCHITECTURE.md](./ARCHITECTURE.md).

Everything runs in Docker. See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup; the short version:

```bash
make setup   # build, install deps, create & seed the database
make dev     # start api :3000, web :3001, admin :3002
```

### Secrets in local development

You do **not** need any secret to run CardJoy locally. `config/credentials/development.key` is
gitignored and never committed, so on a fresh clone `Rails.application.credentials` decrypts to an
empty hash — that is expected.

Anything local dev genuinely needs therefore reads an env var, falling back to credentials. The JWT
signing secret works this way (`config.x.jwt_secret` in `config/application.rb`), and
`docker-compose.yml` sets a throwaway `JWT_SECRET_KEY` for the `api` service. If you run the API
outside Docker, export one yourself:

```bash
export JWT_SECRET_KEY=local-development-jwt-secret-do-not-use-in-production
```

Without it, the API refuses to boot and tells you to set one
(`config/initializers/jwt_secret.rb`). That check is deliberate: `JWT.encode` signs happily with a
nil key, so a missing secret used to let `signIn` return a token the API could never verify — every
request was anonymous and sign-in appeared to succeed while silently doing nothing.

`credentials:edit` does not run initializers, so a missing secret is still fixable through it.

### PostGrid (physical mail)

Printing and mailing cards goes through PostGrid. It is entirely optional: with no key configured
`PostGrid.configured?` is false, address verification reports itself unavailable, and nothing else
in the app changes — the same gating GIPHY, Unsplash, and PostHog get on the frontend. **You do not
need a PostGrid key to develop, and CI does not have one.**

Three env vars, each falling back to `credentials.post_grid.*`:

| Env var | Credential | Purpose |
|---|---|---|
| `POSTGRID_API_KEY` | `post_grid.api_key` | The live key. Mails real cards and bills real money. |
| `POSTGRID_TEST_API_KEY` | `post_grid.test_api_key` | The test key. Everything runs, nothing is printed. |
| `POSTGRID_MODE` | `post_grid.mode` | `live` or `test`; anything else reads as `test`. |

`POSTGRID_MODE` is a separate switch from `RAILS_ENV` on purpose. Nothing in `app/services/post_grid`
looks at `Rails.env`: the proof run uses the **test** key from **production**, and a staging box that
happens to boot as `production` must not start mailing postcards to real people.

**This repo is public. Never commit a key, live or test** — not in a credentials file, not in a spec,
not in a fixture. The specs use an obviously fake `test_sk_…` string.

### Holiday card print rendering

`HolidayCard::PrintRenderer.new(card).render` turns a card into `{ front:, back: }` — the two HTML
documents PostGrid prints. It takes a card and returns two strings; it is deliberately **not**
coupled to PostGrid, makes no HTTP calls, and can be exercised with nothing stubbed.

It combines two things that know nothing about each other: `HolidayCardCatalogue` owns the geometry
(where `photo_2` sits, in inches), and `HolidayCard#design_config` owns the content (which photo,
panned and zoomed how). Rules worth knowing before you touch it:

- **Inches and points, never pixels.** A pixel value bakes in an assumed DPI, and PostGrid renders
  at print resolution. There is a spec that fails if a `px` appears in the output.
- **Absolute positioning only**, at catalogue coordinates offset by the 0.125" bleed. No flexbox,
  no grid — those are where our renderer and PostGrid's would diverge.
- **Everything is clipped.** Photo slots and text regions are `overflow: hidden`, so nothing can
  spill into the reserved address block on the back panel.
- **Fonts are vendored and inlined as base64** from `app/assets/holiday_card_fonts` — only the ones
  a panel actually paints with. See that directory's README before adding a font.
- **`design_config` is untrusted.** Text is escaped; font, size, alignment, and colour are checked
  against allow-lists before they reach the CSS.

The pan/zoom CSS the renderer emits is the contract the editor preview has to reuse verbatim. Two
implementations of the cropping maths is how the on-screen proof stops matching the printed card.

## Before you start

1. Work from an issue with clear **acceptance criteria** (the feature-request form captures these).
2. Branch off `main`: `git checkout -b feat/<short-name>`.
3. Restate the scope in your own words before writing code — what the change adds and how you'll
   verify it against the acceptance criteria.

## Quality gates (what CI checks)

Run `make check` before opening a PR. It runs everything CI runs:

| Area | Command | CI job |
|------|---------|--------|
| Ruby style | `docker compose exec api bundle exec rubocop` | `api-ci` / Rubocop |
| Ruby types | `docker compose exec api bundle exec srb tc` | `api-ci` / Sorbet |
| Ruby tests | `docker compose exec api bundle exec rspec` | `api-ci` / RSpec |
| web/admin lint | `yarn lint` in each | `web-ci` / `admin-ci` |
| web/admin format | `yarn format-check` in each | `web-ci` / `admin-ci` |
| web/admin build | `yarn build` (tsc) in each | `web-ci` / `admin-ci` |

> If Sorbet complains about a gem or a generated method after you add code, regenerate the RBIs the
> way CI does: `docker compose exec api bundle exec tapioca gems` and
> `docker compose exec api bundle exec tapioca dsl`, then re-run `srb tc`.

The `/checks`, `/lint`, and `/rspec` skills run these for you.

---

## Backend: add a GraphQL mutation

The backend exposes a single `/graphql` endpoint. A write is a `Mutations::*` class registered on
`MutationType`. Reference implementation: `api/app/graphql/mutations/create_card.rb` and its spec
`api/spec/graphql/mutations/create_card_spec.rb`.

Steps:

1. **Model + migration** (only if you need new data):
   ```bash
   docker compose exec api ./bin/rails generate migration AddFooToCards foo:string
   docker compose exec api ./bin/rails db:migrate
   ```
   Add validations/associations to the model in `app/models/`.

2. **Mutation class** in `app/graphql/mutations/<name>.rb`. Follow the house style: `# typed: true`,
   subclass `BaseMutation`, declare `argument`s and `field`s (always include an
   `errors: [String]` field), and read the caller via `context[:current_user]`:

   ```ruby
   # typed: true
   module Mutations
     class CreateFoo < BaseMutation
       argument :name, String, required: true

       field :foo, Types::FooType, null: true
       field :errors, [ String ], null: false

       def resolve(name:)
         user = context[:current_user]
         return { foo: nil, errors: [ "Not authenticated" ] } unless user

         foo = user.foos.build(name:)
         if foo.save
           { foo:, errors: [] }
         else
           { foo: nil, errors: foo.errors.full_messages }
         end
       end
     end
   end
   ```

3. **Object type** in `app/graphql/types/<name>_type.rb` (subclass `Types::BaseObject`), exposing the
   fields the frontend needs. See `types/card_type.rb` for an example.

4. **Register the mutation** on `app/graphql/types/mutation_type.rb`:
   ```ruby
   field :create_foo, mutation: Mutations::CreateFoo
   ```

5. **Factory** in `spec/factories/<name>s.rb` (mirror `spec/factories/cards.rb`).

6. **Request spec** in `spec/graphql/mutations/<name>_spec.rb`, `type: :request`. Authenticate by
   encoding a JWT and sending it as a Bearer header, POST the GraphQL query to `/graphql`, and assert
   on the JSON response — see `create_card_spec.rb` for the exact pattern (including file uploads via
   the multipart `map`).

7. **Run the gates**: `rubocop`, `srb tc` (regenerate RBIs if needed), `rspec`.

## Backend: add a query field

Add a `field` to `app/graphql/types/query_type.rb` and implement its resolver method there (or a
resolver class). Return existing `Types::*` objects. Add a request spec under `spec/graphql/`.

---

## Frontend: add a page / wire up the API

The consumer app is `web/`; the admin app is `admin/` (same stack). Reference implementation:
`web/src/pages/Card/New.tsx` (queries + a mutation) and `web/src/lib/apollo-client.ts`.

Steps:

1. **Page component** in `web/src/pages/<Feature>/<Name>.tsx`. Use Apollo hooks with inline `gql`
   documents, mirroring `Card/New.tsx`:

   ```tsx
   import { gql, useQuery, useMutation } from '@apollo/client';
   import { useNavigate } from 'react-router-dom';

   const CREATE_FOO = gql`
     mutation CreateFoo($input: CreateFooInput!) {
       createFoo(input: $input) {
         foo { id name }
         errors
       }
     }
   `;

   export default function FooNew() {
     const navigate = useNavigate();
     const [createFoo] = useMutation(CREATE_FOO);
     // ...render a form; on submit call createFoo({ variables: { input } })
   }
   ```

   Relay-style mutations take a single `input:` object. Always read and surface the `errors` array.

2. **Route** in `web/src/App.tsx`: import the page and add a `<Route path="..." element={<FooNew />} />`
   inside `<Routes>`.

3. **UI**: compose from `web/src/components/ui/` (shadcn/ui). Match the existing components' styling
   rather than introducing new UI primitives.

4. **Run the gates**: `yarn lint`, `yarn format-check` (or `yarn format` to fix), `yarn build`.

Apollo config (`src/lib/apollo-client.ts`) already injects the JWT from `localStorage` and points at
`VITE_GRAPHQL_ENDPOINT`, so authenticated calls work automatically once the user is signed in.

---

## Opening the PR

- Keep the PR focused on one logical change.
- Fill in the PR template, including `Closes #<issue>`.
- Confirm `make check` is green.
- Commit messages follow `<type>(<scope>): <description>` (e.g. `feat(api): add foo mutation`).
