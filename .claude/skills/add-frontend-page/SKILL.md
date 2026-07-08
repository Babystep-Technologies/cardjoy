---
name: add-frontend-page
description: Scaffold a new React page wired to the GraphQL API following CardJoy conventions
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Add a frontend page

Create a new page in the consumer app (`web/`) or admin app (`admin/`) the way CardJoy does it. Read
[docs/DEVELOPMENT.md](../../../docs/DEVELOPMENT.md) for the full pattern; the reference
implementation is `web/src/pages/Card/New.tsx` with `web/src/lib/apollo-client.ts`.

## Steps

1. **Read the references first**: `web/src/pages/Card/New.tsx` (queries + mutation + navigation),
   `web/src/App.tsx` (routing), and a few `web/src/components/ui/*` to reuse.

2. **Page component** `web/src/pages/<Feature>/<Name>.tsx`:
   - Use Apollo hooks with inline `gql` documents (`useQuery`, `useMutation`).
   - Relay-style mutations take a single `input:` object variable.
   - Always read and surface the `errors` array returned by mutations.
   - Build the UI from existing `src/components/ui/` (shadcn/ui) components; match current styling.

   ```tsx
   import { gql, useMutation } from '@apollo/client';
   import { useNavigate } from 'react-router-dom';

   const CREATE_FOO = gql`
     mutation CreateFoo($input: CreateFooInput!) {
       createFoo(input: $input) { foo { id name } errors }
     }
   `;

   export default function FooNew() {
     const navigate = useNavigate();
     const [createFoo] = useMutation(CREATE_FOO);
     // render a form; on submit: await createFoo({ variables: { input } })
   }
   ```

3. **Route** in `web/src/App.tsx`: import the page and add a
   `<Route path="/foo/new" element={<FooNew />} />` inside `<Routes>`.

4. For the **admin** app, do the same under `admin/src/` (same stack).

## Gates

Run before finishing (or use the `/lint` and `/checks` skills):

```bash
docker compose exec web yarn lint
docker compose exec web yarn format-check    # or `yarn format` to fix
docker compose exec web yarn build           # tsc type-check + vite build
```

Apollo already injects the JWT and targets `VITE_GRAPHQL_ENDPOINT`, so authenticated calls work once
the user is signed in — no extra wiring needed.
