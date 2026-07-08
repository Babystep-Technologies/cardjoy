---
name: add-graphql-mutation
description: Scaffold a new GraphQL mutation in the Rails API following CardJoy conventions
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Add a GraphQL mutation

Create a new write operation in the Rails API the way CardJoy does it. Read
[docs/DEVELOPMENT.md](../../../docs/DEVELOPMENT.md) for the full pattern; the reference
implementation is `api/app/graphql/mutations/create_card.rb` and its spec
`api/spec/graphql/mutations/create_card_spec.rb`.

## Steps

1. **Read the references first** so the new code matches house style: `create_card.rb`,
   `create_card_spec.rb`, `app/graphql/types/mutation_type.rb`, and a `types/*_type.rb`.

2. **Data (only if needed):** generate and run a migration; add validations/associations to the
   model.
   ```bash
   docker compose exec api ./bin/rails generate migration <Name> <field:type>
   docker compose exec api ./bin/rails db:migrate
   ```

3. **Mutation class** `app/graphql/mutations/<name>.rb`:
   - `# typed: true`; subclass `BaseMutation`.
   - Declare `argument`s and `field`s; **always** include `field :errors, [ String ], null: false`.
   - Read the caller via `context[:current_user]`; return `{ ..., errors: [...] }` on failure and
     return early with `"Not authenticated"` when a user is required.
   - Wrap multi-step writes in `ApplicationRecord.transaction`.

4. **Object type** `app/graphql/types/<name>_type.rb` (subclass `Types::BaseObject`) exposing the
   fields the client needs.

5. **Register** the mutation on `app/graphql/types/mutation_type.rb`:
   `field :<snake_name>, mutation: Mutations::<Name>`.

6. **Factory** `spec/factories/<name>s.rb` (mirror `spec/factories/cards.rb`).

7. **Request spec** `spec/graphql/mutations/<name>_spec.rb`, `type: :request`: build a JWT, send it as
   a Bearer header, POST the GraphQL query to `/graphql`, assert on the JSON. Copy the structure of
   `create_card_spec.rb`.

## Gates

Run before finishing (or use the `/checks` skill):

```bash
docker compose exec api bundle exec rubocop
docker compose exec api bundle exec srb tc     # if it complains, regenerate RBIs (see below)
docker compose exec api bundle exec rspec spec/graphql/mutations/<name>_spec.rb
```

If Sorbet flags generated methods after adding a model/mutation:

```bash
docker compose exec api bundle exec tapioca gems
docker compose exec api bundle exec tapioca dsl
docker compose exec api bundle exec srb tc
```
