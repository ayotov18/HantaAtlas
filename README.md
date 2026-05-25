# HantaAtlas

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-black?logo=apple)
![Backend](https://img.shields.io/badge/backend-Node%2022%20·%20Fastify-3178c6?logo=node.js&logoColor=white)
![Map](https://img.shields.io/badge/map-Mapbox-4264fb?logo=mapbox&logoColor=white)
![Vibecoded](https://img.shields.io/badge/⚠️-vibecoded-ff5f1f)

> **Heads up: this is a vibecoded project.** It's an iPhone-first, source-led
> outbreak reference app (hantavirus + Ebola) with a small Node backend, built
> largely by prompting LLMs. Provided as-is — see [Vibe Code Alert](#vibe-code-alert).

HantaAtlas answers one question: **what has been officially reported, where, when,
and by whom?** It plots official outbreak signals on a world map, a country feed,
and saved watchlists, with source provenance attached to every data point. It is
**informational only** — no diagnosis, no risk scoring, no treatment advice, no
predictions. No ads, no third-party tracking.

In a bit more detail, the repo has three parts:

1. **iOS app** — SwiftUI (iOS 26+), a Mapbox world map, and Sign in with Apple.
   It renders bundled fixtures offline and talks to the backend through a single
   configurable `API_BASE_URL`, so you can point it at your own server.
2. **Backend** — a Fastify + TypeScript API with versioned, stable `/v1/*`
   endpoints, plus a source-ingestion worker that pulls official feeds (WHO
   Disease Outbreak News, RSS sources) into PostgreSQL via Prisma. It is
   fixture-backed by design, so the API runs with or without live connectors.
3. **Marketing** — an optional static Next.js site.

## Vibe Code Alert

This project was 99% vibe coded as a fun hack. I'm not going to support it in any
way, it's provided here as is for other people's inspiration and I don't intend to
improve it. Code is ephemeral now and libraries are over, ask your LLM to change it
in whatever way you like.

## Stack

| Layer | Tech |
|-------|------|
| iOS app | Swift 6, SwiftUI, iOS 26+, Mapbox Maps SDK |
| API | Node 22, Fastify, TypeScript (ESM), Zod |
| Data | PostgreSQL 16, Prisma ORM |
| Worker | TypeScript ingestion adapters (WHO DON, RSS) |
| Marketing | Next.js (static export), Tailwind, Radix |
| Infra | Docker Compose, nginx / Caddy, Cloudflare Tunnel |

## Setup

### 1. Run the backend

```sh
cp .env.example .env          # set POSTGRES_PASSWORD at minimum
docker compose up --build     # postgres + api + worker
docker compose exec api npm run prisma:seed   # first run only
```

The API is now on `http://localhost:3000` — check it: `curl localhost:3000/health`.

### 2. Reach the backend from an iOS **device**

`localhost` works for the **Simulator**, but a physical iPhone can't reach your
Mac's localhost, and iOS requires HTTPS for non-local hosts. To run on a device,
expose the API on a domain you control (all free):

- **Quick tunnel (throwaway URL):** `cloudflared tunnel --url http://localhost:3000`
- **Your own domain, no public IP:** create a free Cloudflare named tunnel, set
  `CLOUDFLARE_TUNNEL_TOKEN` in `.env`, then `docker compose --profile tunnel up`.
- **Public domain + open ports 80/443:** `APP_DOMAIN=api.example.com ACME_EMAIL=you@example.com docker compose --profile proxy up` (Caddy auto-HTTPS).

> Why not Tailscale Funnel / ngrok? Funnel only serves `*.ts.net` (no custom
> domains) and has a known iOS TLS issue; ngrok's free tier is random-URL only.

### 3. Run the iOS app

1. Open `ios-app/HantaAtlas.xcodeproj` in Xcode 26+.
2. **Mapbox token** — create a free public token at
   <https://account.mapbox.com/access-tokens/> and replace
   `pk.PUT_YOUR_MAPBOX_TOKEN_HERE` in both `ios-app/HantaAtlas/Info.plist`
   (`MBXAccessToken`) and `ios-app/HantaAtlas/Resources/MapboxAccessToken`.
3. **Point at your backend** — set `API_BASE_URL` in `ios-app/HantaAtlas/Info.plist`:
   `http://localhost:3000` for the Simulator, or your tunnel/proxy HTTPS URL on a
   device. (`APIClient.resolvedBaseURL` resolves it once; all calls route through it.)
4. Build & run. Sign in with Apple needs a paid Apple Developer team; everything
   else renders from bundled fixtures even with no backend.

### Common commands

```sh
npm install
npm run build            # tsc (backend/api + backend/worker)
npm test                 # vitest
npm run prisma:migrate   # prisma migrate deploy
xcodebuild -project ios-app/HantaAtlas.xcodeproj -scheme HantaAtlas \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Node 22 required. Backend workspaces are ESM (relative imports use `.js` suffixes).

## License

TODO: add a license before relying on this (e.g. MIT or Apache-2.0).
