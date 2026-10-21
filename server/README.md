# Holy Moley community level service

This is the small HTTP service behind the editor's **ONLINE** panel. It accepts
published Level Forge JSON, lists what has been published, and serves a level
back when someone presses **LOAD**.

It uses only the Python standard library. Levels live in one JSON document,
either in a local file under the data directory or in a free Upstash Redis
database when the two `UPSTASH_REDIS_REST_*` variables are set. CORS is open so
the Web export can use the same service.

## Run it locally

From the repository root:

```sh
python server/level_server.py --port 8787 --data-dir server/data
```

The game client is hardwired to the hosted service, so to test against this
local server, temporarily change `SERVICE_URL` in `scripts/level_share.gd` to
`http://127.0.0.1:8787`. The panel still remembers the author name in
`user://level_share.cfg`.

## Deploy it

The service is a normal Python process. Any host that can run Python 3.10+ or a
container works.

There are two storage modes:

- **Local file (default):** keep `levels.json` on persistent storage.
- **Upstash Redis:** set `UPSTASH_REDIS_REST_URL` and
  `UPSTASH_REDIS_REST_TOKEN` and the service stores the same JSON document in
  Upstash. This survives hosts with an ephemeral filesystem, including Render's
  free web services.

Build and run the included container with a local volume:

```sh
docker build -t holy-moley-levels server
docker run -p 8787:8787 -v holy-moley-levels-data:/app/data holy-moley-levels
```

For a hosted deployment, set `PORT` if the host provides one. A local run binds
`127.0.0.1` by default; pass `--host 0.0.0.0` when running outside a container
and accepting connections from another machine. A Python host can use:

```sh
python level_server.py --host 0.0.0.0 --data-dir /app/data
```

The included Docker image already passes `--host 0.0.0.0`.

### Render (free) + Upstash (free)

The repository includes a `render.yaml` Blueprint that uses Render's free web
service. Because that filesystem is ephemeral, it expects a free Upstash Redis
database for storage.

1. Create a Redis database at <https://console.upstash.com/redis>. The free plan
   does not require a card.
2. Open the database's **REST** connection details and copy the REST URL and
   standard token.
3. Push the repository to GitHub/GitLab.
4. In the Render Dashboard choose **New > Blueprint**, connect the repo, and
   enter the Upstash URL and token when prompted for the two secrets.
5. Deploy. Render builds `server/Dockerfile` and creates a free web service with
   a health check at `/health` and `PORT=8787`.

Free-tier expectations:

- Upstash free currently includes 250 MB of data, 500K commands/month and 10 GB
  of bandwidth/month. A publish or download writes the document once; listing is
  served from memory. Startup reads the document once.
- Render free web services spin down after 15 minutes without traffic. The first
  request afterward takes roughly a minute to wake the service; the levels in
  Upstash are unaffected.
- Do not use Render's free Key Value for the level database: its data is lost on
  restart. Render's free Postgres expires after 30 days.

The game is already pointed at `https://holy-moley-levels.onrender.com`, fixed
in `scripts/level_share.gd`. If you deploy the service somewhere else, change
`SERVICE_URL` there; there is no server field in the editor.

If the Web export is served over HTTPS, deploy this service over HTTPS too. A
browser page cannot call an `http://` server from an `https://` page.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Liveness check |
| `GET` | `/` | Small HTML gallery of published levels |
| `GET` | `/api/levels?limit=50&offset=0` | Level summaries, newest first |
| `POST` | `/api/levels` | Publish `{name, author, description, level}` |
| `GET` | `/api/levels/{id}` | Full level and metadata; increments downloads |

IDs are 12 lowercase hex characters. The server caps request bodies at 1 MB,
limits block/enemy/prop counts, and rejects payloads without `blocks` and
`enemies` arrays.

## Operational notes

- There are no accounts, edit tokens or moderation tools. Anyone who can reach
  the service can publish. Add authentication and moderation before treating it
  as a permanent public service.
- Back up the level store. With local storage, `levels.json` is the entire
  community database. With Upstash, copy the value of the configured key (or use
  Upstash's export tools).
- The HTML gallery at `/` is intentionally plain and uses no external assets.
