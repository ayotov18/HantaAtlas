FROM node:22-bookworm-slim AS base
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json* ./
COPY backend/api/package.json backend/api/package.json
COPY backend/worker/package.json backend/worker/package.json
COPY backend/prisma backend/prisma
RUN npm install

FROM deps AS build
COPY backend/api backend/api
RUN npm run prisma:generate && npm run build --workspace backend/api

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=build /app/node_modules node_modules
COPY --from=build /app/backend/api/dist backend/api/dist
COPY --from=build /app/backend/api/package.json backend/api/package.json
EXPOSE 3000
CMD ["node", "backend/api/dist/server.js"]

