# Build stage – run where there is enough RAM (e.g. GitHub Actions ~7GB).
# Railway's build environment often has limited RAM and may kill this step (exit 137).
FROM node:22-bookworm-slim AS builder

RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

WORKDIR /app
COPY . .

# Increase Node heap for Vite/Remix build. Unset VERCEL so Remix uses default
# build output (build/server/index.js), not Vercel's .vercel/output.
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV VERCEL=

RUN pnpm install --frozen-lockfile
RUN pnpm --filter=@webstudio-is/http-client build
RUN pnpm --filter=@webstudio-is/builder build

# Fail the image build if Remix didn't produce the expected file (remix-serve needs it)
RUN test -f /app/apps/builder/build/server/index.js || (echo "Missing build/server/index.js - check Remix build output" && exit 1)

# Run stage – minimal runtime
FROM node:22-bookworm-slim AS runner

RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

WORKDIR /app

# Copy full workspace so pnpm and symlinks resolve (builder needs packages/ and root node_modules)
COPY --from=builder /app/package.json /app/pnpm-lock.yaml /app/pnpm-workspace.yaml /app/
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/packages /app/packages
COPY --from=builder /app/apps /app/apps
# Ensure build output is present (explicit copy so we never run without it)
COPY --from=builder /app/apps/builder/build /app/apps/builder/build

ENV NODE_ENV=production
ENV HOST=0.0.0.0
EXPOSE 3000

# Run migrations then start the app (DATABASE_URL / DIRECT_URL must be set at runtime, e.g. Railway).
WORKDIR /app
CMD pnpm --filter=./packages/prisma-client migrations migrate --cwd apps/builder && cd apps/builder && pnpm start
