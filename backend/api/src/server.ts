import { buildApp } from "./app.js";

const port = Number(process.env.PORT ?? 3000);
// Bind to loopback by default. The reverse proxy (nginx/Caddy) on the same
// host fronts the public port. Override HOST=0.0.0.0 only in dev.
const host = process.env.HOST ?? "127.0.0.1";

const app = buildApp();

try {
  await app.listen({ port, host });
  app.log.info({ host, port }, "HantaAtlas API listening");
} catch (error) {
  app.log.error(error);
  process.exit(1);
}

