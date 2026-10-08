# Multiplayer foundation (developer preview)

The game currently ships **local Faction simulation**. This folder is the first, **opt-in** backend slice and does not activate live multiplayer in the shipped Windows or Android builds.

## Run locally

From the repository root with Python 3.11+:

```sh
python3 -m unittest server.test_app -v
python3 -m server.app --db ./server/data.sqlite --host 127.0.0.1 --port 8765
```

The backend uses SQLite and the Python standard library. Session bearer tokens are generated from a cryptographically secure random source; only SHA-256 hashes are stored. API calls use server-side ownership checks. Currently supported: player creation, Faction creation, view own Faction, leader-created invitations, listing your invitations, accepting invitations, and basic validation/conflict protection. Responses never include other players' session tokens.

Godot adapter: `scripts/faction/OnlineFactionClient.gd`. Instantiate it explicitly in a development scene; it is **not** connected to `FactionManager` yet. Register a user, receive `request_completed("register",201,data)`, and call `set_session(data["session_token"])` in a development controller. **Do not** store that token in the existing plaintext save system.

Example development requests (replace placeholders):

```sh
curl -s -X POST http://127.0.0.1:8765/v1/players -H 'Content-Type: application/json' -d '{"display_name":"Player One"}'
curl -s -X POST http://127.0.0.1:8765/v1/factions -H 'Content-Type: application/json' -H 'Authorization: Bearer <session_token>' -d '{"name":"Night Union","tag":"NU"}'
```

## Security and production limitations

**Do not expose this development server to the public internet.** It lacks TLS termination, an external identity provider, account recovery, brute-force/rate limiting, audited session revocation, monitoring, and database migrations. The player-creation endpoint issues anonymous development identities; this is not a verified identity system. For deployment, use HTTPS/TLS, proper account authentication, request quotas, scalable transactions and migrations, privacy controls, and server-side game state validation.

The API does **not** yet host real-time wars, donations, territory, seasonal rankings, or rewards. None of those local values should be trusted by a future multiplayer server. The local Godot Faction and Dominion managers continue functioning unchanged while this foundation is developed.

Next integration: add authenticated sign-in/account recovery, decide how users switch from local to online Faction state, then move war attacks, contribution accounting and season rewards to server-validated transactions before enabling online gameplay.
