# TAKE THEIR GUN — prototype v0.2

A server-authoritative Roblox multiplayer shooter built around persistent weapon identity. Every real weapon has a unique `GunId`, its own statistics and ownership history, and now its own DataStore record. A Tool or world pickup is only the current presentation of that record.

## v0.2 persistence model

There are now two weapon classes:

- **Persistent weapons (`G-...`)** are real owned guns. Their GunId, current owner, original owner, kill statistics, theft count, owner history, ammo state, and best streak are saved across sessions.
- **Issue weapons (`I-...`)** are temporary fallback guns. They keep the game playable after a player loses their real weapon, but they are never saved to permanent inventory.

Each first-time player receives one persistent founder weapon. Founder weapon type rotates across Pistol, SMG, Assault Rifle, and Shotgun for testing. Once that gun is stolen, the original player does not receive a replacement persistent founder gun.

Player profiles store an index of owned GunIds. Each persistent weapon is stored separately by GunId. On join, ownership references are reconciled against the weapon's authoritative `CurrentOwnerUserId`, so stale player references are removed instead of duplicating guns.

## DataStore setup for Studio testing

Persistence requires Roblox DataStore access.

1. Publish the test experience to Roblox.
2. In Studio open **File → Experience Settings → Security**.
3. Enable **Studio Access to API Services**.
4. Save the experience settings.
5. Stop and restart the local server/client test after changing the setting.

If DataStore access is unavailable, the prototype falls back to session-only behavior and prints one warning instead of repeatedly retrying every save.

## Open with Rojo

From the repository:

```powershell
rojo serve default.project.json
```

Open Roblox Studio, connect the Rojo plugin, then use **Server & Clients** with 3 clients for the ownership tests.

## Controls

| Key | Action |
| --- | --- |
| WASD | Move |
| Mouse | Aim/look |
| Mouse 1 | Fire; hold for automatic weapons |
| R | Reload |
| E | Take nearby dropped gun and swap if armed |
| F | Inspect equipped gun |
| G | Toggle developer GunId registry |
| I | Toggle **My Guns** persistent inventory |
| Space | Jump |

The HUD labels the equipped weapon as either **PERSISTENT** or **ISSUE**.

## v0.2 persistence acceptance pass

Run a 3-client Studio server with DataStore access enabled.

### A. First join

1. Join as Player A.
2. Press `F` and confirm the equipped gun has a `G-` GunId and displays **PERSISTENT WEAPON**.
3. Press `I` and confirm that same GunId appears under **MY GUNS**.
4. Record the GunId.

### B. Rejoin persistence

1. Stop the Studio test completely.
2. Start another server/client test with the same Roblox account.
3. Confirm Player A receives the exact same `G-` GunId rather than a new founder gun.
4. Confirm its kills, headshots, theft count, best streak, and owner history remain intact.

### C. Lost-gun respawn behavior

1. Have Player B kill Player A while A is holding the persistent founder gun.
2. Confirm A's `G-` weapon becomes a physical drop.
3. Let A respawn without reclaiming it.
4. Confirm A now receives an `I-` **ISSUE** pistol instead of a new persistent gun.
5. Press `I`; A should still own the dropped persistent gun until someone steals it.

### D. Persistent theft

1. Have Player C take A's dropped persistent gun with `E`.
2. Confirm the exact same `G-` GunId now shows C as current owner.
3. Press `I` on C and confirm the gun appears in C's persistent inventory.
4. Press `I` on A and confirm the gun no longer appears in A's persistent inventory.
5. Stop the entire Studio test.
6. Start a fresh test.
7. Confirm C still owns that exact GunId and A does not receive it back automatically.

### E. Recovery

1. Have the original owner A steal the gun back from C.
2. Confirm the feed reports **RECOVERED**.
3. Confirm `TimesStolen` does not increment for the recovery.
4. Stop and restart the test.
5. Confirm the recovered GunId is again in A's persistent inventory.

### F. No persistent duplication

1. Kill and respawn repeatedly while a player's real gun remains on the ground.
2. Confirm respawns create only temporary `I-` issue guns.
3. Confirm no additional `G-` founder guns are created for that player.
4. Try simultaneous pickup attempts from two clients; only one player can own the persistent GunId.

## Persistence behavior

- Persistent gun ownership is written before the previous owner's stale profile reference is removed.
- A transfer that cannot be durably saved remains a session state and leaves the previous persisted ownership reference available for reconciliation.
- Autosave runs every 30 seconds for dirty player/weapon state.
- Server shutdown flushes dirty weapon records and player profiles.
- A persistent world drop that reaches `DropLifetime` is stored back to its current owner instead of being destroyed.
- When a player leaves, persistent guns they still own are stored; temporary issue guns are discarded.

## Prototype limitations

- Weapon models, animations, sound, ADS, recoil patterns, hitmarkers, and map art are still placeholders.
- The persistent inventory is currently a read-only prototype panel; selecting loadouts comes later.
- Cross-server high-stakes extraction/locking rules are not implemented yet.
- The debug registry is a development tool and should be disabled before release.
- Roblox Studio multiplayer testing remains the runtime acceptance environment; this repository does not yet include an automated Roblox runtime harness.

## Core invariant

**Weapon class defines what the gun does. GunId defines which individual gun it is.**

The project must never replace a persistent owned GunId with a generic weapon instance when dropping, stealing, recovering, saving, loading, or respawning.
