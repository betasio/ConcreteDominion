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

## Shared server-side war prototype

The Online • Dev panel now supports **Start server war**, **Refresh shared war**, and **Muscle / Convoy / Intel** attacks. Start a war as the Faction leader; invite a second development player and connect from another game instance. Each account can submit at most **3 attacks**, with a total of **6 attacks per war**. The server rotates visible defenses (watchful, fortified, mobile), computes all points, records each player's contributions, and closes the war automatically after six rounds. Two clients can refresh the same SQLite-backed war; this is HTTP polling, **not live push networking**.

Endpoints: `GET /v1/war`, `POST /v1/war/start`, `POST /v1/war/attack` with `{"strategy":"muscle"}` (or convoy/intel). The server does not accept client-supplied damage, contribution, or scores. All war state is independent of the offline Faction War system: no online rewards are credited to local saves.

**Production gaps:** Identity verification, robust sessions, replay-safe idempotency, activity limits, multiple concurrent database workers, matchmaking with real opposing factions, timeouts and forfeits, season settlement, real rewards, and secure deployment. This first war uses an **NPC opponent** and deterministic server-side scoring, with multiple real accounts cooperating in a single Faction.

## Faction versus Faction development matchmaking

Two **different** online Faction leaders can queue through **Online • Dev → Queue Faction (leader)**. The first waits; the second pairs immediately in a shared PvP match. Members then use the dedicated PvP Muscle / Convoy / Intel controls and **Refresh PvP**. Each faction gets six attacks, each player can make at most three, and the match settles only after both sides finish all six. Unlike the earlier NPC war, opposing scores are earned through the other Faction's real accounts.

Endpoints: `GET /v1/pvp`, `POST /v1/pvp/queue`, `POST /v1/pvp/attack`. Each attack must send a unique 32-character lowercase hex `request_id` and a valid `strategy`; replaying the same request from the same player returns the original receipt without adding points. Reusing an ID for a different strategy is rejected. The server computes attack points, scores, winner, and a once-only settlement entry for each Faction in `pvp_ledger` (100 points for winner, 25 loser, 50 each on a draw). These points are **non-spendable development ledger entries**: offline currency and Dominion progression are not changed.

This remains a development preview, not a public multiplayer service. The HTTP server is single-process with SQLite serialization, and the current queue does not support cancellation, timeouts, cross-process transactions, production authentication, seasonal rollover, or full anti-abuse safeguards. The attacking client generates receipt IDs; for production also add durable local pending-request storage so a network timeout can resend the original ID rather than creating a second attack.

## Matchmaking reliability (development)

Faction leaders can **Leave matchmaking queue** before an opponent has been paired. The server removes queue entries older than **15 minutes**. Active PvP matches expire after **24 hours** and are closed with `pvp_timeout` ledger entries granting **zero points** to each side; queued/expired cleanup is performed lazily on API traffic. Timeout settlement does not award a victory and cannot be converted into offline rewards. These durations are development defaults, not live-service policy.

The online Godot adapter holds a pending PvP attack's 32-character request ID **in memory** if a transport error or unusable response occurs. Tapping the **same strategy** again sends the original ID, so the server replies with the first receipt instead of awarding another attack. A definitive JSON server response clears the pending request. Switching development accounts clears the in-memory pending receipt. Since the pending ID is not written to disk, app restarts during a network uncertainty window still require a production-grade durable outbox or request status lookup before issuing a new attack.

## Developer account recovery and restart-safe attack receipts

New development accounts receive a **recovery key** alongside their session token and server player ID. Store both keys in a safe location outside the game. In **Online • Dev**, provide the player ID and recovery key, then press **Recover development account**. A successful recovery rotates **both** keys immediately; the previous session and recovery key cease working. The new keys appear in masked input fields so they can be copied and stored again. Only account records created after this feature have recovery credentials; existing developer accounts without a key cannot be recovered by this endpoint. This is a **development-only** bearer-key recovery mechanism, not a verified-email/password authentication service, and must not be exposed publicly without TLS, rate limiting, account verification, and abuse controls.

For reconnect reliability, the Godot client writes a pending attack's request ID and strategy to a per-session file under `user://` **before** dispatching a PvP attack. The file name is derived from a SHA-256 digest of the session token; **the token itself is never written into the receipt file**. After restarting the game, reconnect with the same session token and submit the same strategy to replay the original request ID. An authoritative successful or client-error JSON response clears the pending receipt; transport errors or server errors retain it for retry. The receipt is intentionally separate from the normal game save and grants no rewards. Rotating an account session does not transfer any pending receipt: reconcile uncertain attacks through server match history before creating another attack on the new session.

## Server-authoritative seasonal PvP rankings

The **Online • Dev → Refresh seasonal leaderboard** button reads `GET /v1/seasons/leaderboard` for authenticated Faction members. Seasons are **28-day UTC epoch-aligned windows**, identified by the window number, with explicit start and end Unix timestamps. Rankings are computed from server-created, timestamped `pvp_ledger` settlements only, sorted by points, wins, and Faction name; the server returns the top 100 and the requesting Faction's rank if present. A timed-out match awards no points. Retrying a previously accepted attack does not create another settlement, and a ledger primary key prevents double entries. Old season scores remain in their own windows rather than being copied forward; a new season starts at zero.

Existing SQLite development databases automatically receive the settlement timestamp column. Historical settlement records that predate timestamps are assigned their migration time because their original settlement dates are unknown. Leaderboard values are **development-only and non-spendable**. No offline rewards or season progression are changed. Production requirements still include verified accounts, abuse/rate limits, durable workers and transactions, and operational monitoring.

## Completed PvP seasons, prestige and Hall of Fame

The authenticated `GET /v1/seasons/history` endpoint finalizes **expired 28-day UTC seasons** when requested (lazy rollover) and returns read-only champion history and the calling Faction's cosmetic badges. Finalized snapshots are written transactionally to `season_archives` and `season_awards`; repeated requests do not create duplicate awards. Only Factions with positive settled points receive a badge: **CHAMPION** for first, **RUNNER_UP** for second, **PODIUM** for third, and **VETERAN** for other contributing Factions. Each archived record stores the Faction name/tag, rank, points, and wins at finalization. The Online • Dev panel includes **Refresh completed seasons** to display your Faction's badges and historical champions.

This is a cosmetic record of development multiplayer competition: it cannot grant cash, cosmetics to the offline inventory, or other game progression, and it is not production identity verification. Rollover requires an API request; no scheduled worker runs. Archives represent the authoritative settlement ledger as observed at finalization and are not re-ranked later. Deployments must ensure timely settlement, durable multi-worker locking, and auditable season close rules before using the system for public competitions.

## Public Faction and player identity (development)

The **Online • Dev → Online Identity** section allows leaders to choose one server-approved Faction **emblem** (crown, serpent, shield, wolf) and **banner** (obsidian, crimson, gold, steel). A member can feature a **CHAMPION, RUNNER_UP, PODIUM, or VETERAN** badge only if their current Faction has a matching archived award; no client may invent earned prestige. The player may clear their featured badge. Anyone with a developer account can view a public Faction profile by ID or their own player profile. Public profiles show names, approved cosmetic choices, and recorded awards but **never** session or recovery keys.

Endpoints: `POST /v1/profiles/faction` (leader only), `POST /v1/profiles/badge` (earned badge only), `GET /v1/profiles/faction/<id>`, and `GET /v1/profiles/player/<id>`. Visual assets remain symbolic text labels in this developer preview; no custom uploaded images or public moderation pipeline is provided. Public in this context means readable by authenticated developer accounts on the private test server, **not publicly deployed**. This identity layer does not grant game stats, currency, or combat benefits.

## Illustrated online Faction profile cards

The Godot **Online • Dev** identity section includes a scalable vector-drawn Faction card (`FactionIdentityCard.gd`). It depicts the four approved emblems (crown, serpent, shield, wolf), uses the selected server-approved banner palette, and accents saved seasonal prestige. Style selectors provide a local preview before the Faction leader saves the changes. Viewing another Faction loads its server-owned identity and historical prestige. The art is generated locally from Godot drawing commands; no arbitrary user-uploaded images are supported and no offline gameplay rewards are affected.

## PvP War Room and rivalry history

The **Online • Dev → Refresh past matchups and rivals** button reads `GET /v1/pvp/history` as an authenticated Faction member. The server returns the **20 latest completed PvP matches** for your Faction, including each opponent's approved emblem and banner, both final scores, attack counts, result, and match ID. The opponent summary groups those recent matches into head-to-head **wins, losses, draws and timeouts**. A timeout is not a draw or victory. Data is derived from the server's immutable match/settlement records, not client score uploads; the display grants no offline rewards.

This is a recent-history preview: the rivalry aggregates cover only the returned 20 matches, not all lifetime battles, and the opponent's cosmetic identity reflects its current profile. Existing PvP records already in SQLite remain available without migration. The developer panel currently shows a text archive alongside the existing illustrated live-match cards.

## Direct rivalry challenges and rematches

The Online • Dev panel includes **Rivalry Challenges**, with a challenge target field, inbox refresh, and leader-only accept, decline and cancellation. Copy a previous opponent's Faction ID from the **PvP War Room** to send a direct challenge. Only Factions with an already settled match against each other can be challenged; no self-challenges or unrelated Factions. Both sides must be free of active PvP and random matchmaking queues when a challenge is sent or accepted. The opposing leader can accept to open a shared PvP match, or decline. The challenger can cancel before acceptance. Pending invitations expire after 24 hours when the API receives traffic. Accepting the same challenge again returns the original match ID rather than creating a second match.

Developer endpoints: `GET /v1/pvp/challenges`, `POST /v1/pvp/challenges` with `{"target_faction_id":"<id>"}`, and `POST /v1/pvp/challenges/<challenge_id>/accept`, `/decline`, or `/cancel`. Standard server-validated PvP attacks, match settlement, ranking and rivalry history apply to rematches. No offline rewards are granted, and this remains a local development backend rather than publicly deployed matchmaking.
