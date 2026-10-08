# Multiplayer foundation (developer preview)

The game currently ships **local Faction simulation**. This folder is the first, **opt-in** backend slice and does not activate live multiplayer in the shipped Windows or Android builds.

## Run locally

From the repository root with Python 3.11+:

```sh
python3 -m unittest server.test_app -v
python3 -m server.app --db ./server/data.sqlite --host 127.0.0.1 --port 8765
```

The backend uses SQLite and the Python standard library. Session bearer tokens are generated from a cryptographically secure random source; only SHA-256 hashes are stored. API calls use server-side ownership checks. Currently supported: player creation, Faction creation, view own Faction, leader-created invitations, listing your invitations, accepting invitations, and basic validation/conflict protection. Responses never include other players' session tokens.

Godot adapter: `scripts/faction/OnlineFactionClient.gd`. The game has a separate **Online • Dev** button and screen (`OnlineFactionUI`), connected to this adapter. Run the server locally before opening that screen. Use **Create developer player**, copy the one-time token from the masked session field (the field can be selected/copied), and then refresh your server Faction. You can create a Faction or invite another registered player by their server player ID. On a second game session, paste that player's developer token into **Connect session** and refresh invitations to accept. Sessions remain **memory-only**; the game does not write them into normal saves, so you must keep the token outside the game for future development sessions.

`OnlineFactionUI` is deliberately isolated from the existing `FactionManager`: it shows authoritative server membership, while campaign, offline Faction progress, wars, and resources remain local prototype systems. This is **not a conversion** of existing local Factions.

The default API URL is `http://127.0.0.1:8765`, which works only when Godot and the backend run on the same computer. To connect from a phone or another device, deploy a private **HTTPS** development endpoint and configure the client URL; never expose the built-in Python server directly on the internet.

Example development requests (replace placeholders):

```sh
curl -s -X POST http://127.0.0.1:8765/v1/players -H 'Content-Type: application/json' -d '{"display_name":"Player One"}'
curl -s -X POST http://127.0.0.1:8765/v1/factions -H 'Content-Type: application/json' -H 'Authorization: Bearer <session_token>' -d '{"name":"Night Union","tag":"NU"}'
```

## Security and production limitations

**Do not expose this development server to the public internet.** It lacks TLS termination, an external identity provider, account recovery, brute-force/rate limiting, audited session revocation, monitoring, and database migrations. The player-creation endpoint issues anonymous development identities; this is not a verified identity system. For deployment, use HTTPS/TLS, proper account authentication, request quotas, scalable transactions and migrations, privacy controls, and server-side game state validation.

The API does **not** yet host real-time wars, donations, territory, seasonal rankings, or rewards. None of those local values should be trusted by a future multiplayer server. The local Godot Faction and Dominion managers continue functioning unchanged while this foundation is developed.

Next integration: add authenticated sign-in/account recovery, decide how users switch from local to online Faction state, then move war attacks, contribution accounting and season rewards to server-validated transactions before enabling online gameplay.
