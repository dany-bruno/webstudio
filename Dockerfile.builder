# Build stage – run where there is enough RAM (e.g. GitHub Actions ~7GB).
# Railway's build environment often has limited RAM and may kill this step (exit 137).
FROM node:22-bookworm-slim AS builder

RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

WORKDIR /app
COPY . .

# Increase Node heap for Vite/Remix build
ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN pnpm install --frozen-lockfile
RUN pnpm --filter=@webstudio-is/http-client build
RUN pnpm --filter=@webstudio-is/builder build

# Run stage – minimal runtime
FROM node:22-bookworm-slim AS runner

RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

WORKDIR /app

# Copy full workspace so pnpm and symlinks resolve (builder needs packages/ and root node_modules)
COPY --from=builder /app/package.json /app/pnpm-lock.yaml /app/pnpm-workspace.yaml /app/
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/packages /app/packages
COPY --from=builder /app/apps /app/apps

ENV NODE_ENV=production
ENV HOST=0.0.0.0
EXPOSE 3000

WORKDIR /app/apps/builder
CMD ["pnpm", "start"]
