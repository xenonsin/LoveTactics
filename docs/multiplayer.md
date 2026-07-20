# Multiplayer

Two ways to fight another player, sharing almost everything below the surface.

**Asynchronous — a build.** A player assembles a team at the Dueling Grounds and publishes it; it is
then fought by other players while its author is offline. What makes it a fight rather than a target
dummy is that the *tactics travel with the roster*: `AI.rulesFor` already ranks a player's authored
`aiRules` above the blueprint's and the posture's, so a restored build opens the way its author
taught it to. Needs no network at all.

**Live — a duel.** Two players, one board, over Steam. Lockstep: both machines run the same
deterministic simulation and exchange only *intent*, verifying with a state fingerprint every turn.

## The stack

| module | job |
|---|---|
| `models/build.lua` | a team + its authored tactics, frozen; normalization |
| `models/builds.lua` | publish / list / pick, behind a swappable backend |
| `models/command.lua` | the five things one duellist tells the other, and their validation |
| `models/state_hash.lua` | the fingerprint two peers compare |
| `models/netplay.lua` | the session: handshake, turn relay, desync detection |
| `models/transport.lua` | the byte-moving seam, and the build gate over it |
| `models/transport_socket.lua` | localhost TCP — **development only** |
| `models/transport_steam.lua` | Steam relay — the only path in a release build |
| `models/steam.lua` | loading luasteam once, and admitting when it is absent |

## Testing it

Most of it needs no network. In order of cost:

1. **`tests/netplay_spec.lua`** — two simulations in one process, same commands, fingerprinted after
   every one. Where most netcode bugs die.
2. **`tests/netplay_session_spec.lua`** — the whole protocol over a loopback pair.
3. **Two windows on one machine** — a real socket:
   ```
   love . duel host auto
   love . duel join auto
   ```
   Each prints `RESULT n/n turns compared agreed`. Development builds only.

Each instrument has a blind spot the others cover; `tests/netplay_spec.lua`'s header spells them out.

## FUTURE WORK

### Binaries are not vendored

Three files are needed beside the executable before any Steam path can work. **All three are
gitignored** — they are large, platform-specific and separately licensed, and the app id is a local
development detail rather than a property of the game. Nothing breaks without them:
`models/steam.lua` reports "not available" with a reason, the game runs normally, and asynchronous
build PvP needs no Steam at all.

| file | where from |
|---|---|
| `luasteam.dll` | <https://github.com/uspgamedev/luasteam/releases> (v5.0.0; rename the download) |
| `steam_api64.dll` | Steamworks SDK v1.64, <https://partner.steamgames.com> — or from an open-source integration's release (GodotSteam, Steamworks.NET, Facepunch.Steamworks), which redistribute it |
| `steam_appid.txt` | created by hand; your App ID |

Plus the Steam client running.

A note on `steam_api64.dll`: almost every Steam game ships one, so there is very likely a copy
already on any development machine. Fine for a local experiment — but the version is not visible
from the file (Valve versions it on its own scheme, not the SDK's), and a mismatch close enough to
*load* while being subtly wrong at the ABI will look like a protocol bug rather than a binary
problem. If Steam behaves strangely, suspect the DLL before the netcode. For a release build, take
it from the Steamworks SDK you are licensed under.

### The Steam invite flow is not written

`models/transport_steam.lua` carries messages once it has a peer's SteamID. Getting that id —
ISteamFriends invites, ISteamMatchmaking lobbies — does not exist yet, and the PvP panel therefore
offers asynchronous builds only.

**This cannot be developed against appid `480`.** Spacewar is a restricted test appid: overlay,
friends and achievements work, but `createLobby()` is accepted and silently creates nothing, and the
overlay invite dialog needs a lobby. It requires a real App ID, which means the $100 Steam Direct
fee (per app, non-refundable, recoupable against the first $1,000 of revenue).

Nothing ever needs *uploading* to Steam to test — `steam_appid.txt` is what lets a local build
present itself as an app.

### Four calls remain unverified

`steamApi()` in `models/transport_steam.lua` is the only code here never run against real Steam.
Everything around it goes through an injectable adapter and is specced against a double. When Steam
misbehaves, look there first.

### Also outstanding

- **A server for builds.** `Builds.backend` is four functions over strings; the local-disk
  implementation is swapped by replacing one table.
- **Draft mode**, and tier-based matching once it exists. Until then normalization is the only
  fairness rule — there is deliberately no prestige bracket (see `models/build.lua`).
- **Forfeit, rematch, per-turn timeouts.** Reconnection is out of scope for v1.
- **`Debug.enabled` must be `false` in a release build** (`models/debug.lua`). It gates the
  localhost duel transport and the `love . duel` harness.
