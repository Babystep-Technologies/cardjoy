# Node 22 (LTS) — matches the project's @types/node and ships yarn. Pinned to
# avoid `node:latest` drift (now Node 26, which no longer bundles yarn/corepack).
FROM node:22

WORKDIR /app/web

# Install dependencies first so this layer is cached unless the manifests change.
COPY package.json yarn.lock ./
RUN yarn install

# Add the rest of the client code
COPY . /app/web

CMD ["node"]
