# Stage 1: Build
FROM node:20-alpine AS build

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

# Stage 2: Serve
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

# stock nginx needs root to bind :80 and write
# /var/cache/nginx; switching to a non-root USER requires the unprivileged image and a port
# change across compose + the launcher. Local-dev container, not a public-facing service:
# exempt per global CLAUDE.md section 9. Revisit if this is ever exposed beyond localhost.
# nosemgrep: dockerfile.security.missing-user.missing-user
CMD ["nginx", "-g", "daemon off;"]