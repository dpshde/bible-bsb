# Hidden Word sync (watch)

Watch bookmarks sync as Hidden Word highlights in a color named **Bookmarks** (SPEC §1.2),
over the v1 server protocol (SPEC §5). Off unless Garmin Connect settings give a sync key and
"Sync bookmarks" is on. Code: `source/HwSync.mc` (sync + mapping), `HwCrypto.mc`, `HwJson.mc`;
tests: `test/HwSyncTest.mc`.

## Contract (Forge prod review, 2026-11-03)

Forge confirmed the v1 wire format is stable (changes are additive; breaking ones go to `/v2`).
The watch follows it like this:

| Area | Watch behavior |
| --- | --- |
| Merge (§3) | Larger `updated` wins (missing / non-integer = 0). Tie: the JSON text larger as UTF-8 bytes wins (byte by byte, then longer), same as `compareVersions` in the reference client. Local writes use `updated = max(now, previous + 1)`. |
| Items (§5.3) | Blob = base64url, no padding, of `nonce(12) ‖ ciphertext ‖ tag(16)`; AAD = ASCII item id; plaintext space-padded to a multiple of 256 bytes (min 256); trailing spaces stripped on read. An item whose decrypted `kind`+`ref` doesn't HMAC to its id is skipped (counted as `skipped=` in the log). |
| New color | `{"kind":"color","ref":"c-<8 random hex>","name":"Bookmarks","hex":"#C89D54","created":now,...}`, only created after a complete pull found no live Bookmarks color. |
| Duplicate Bookmarks colors | After a complete pull the watch uses the live color named Bookmarks with the lowest `created` (missing = 0), then the lowest ref. If that changes (for example an older one turns up), the watch keeps its bookmarks and adds parts in the chosen color; parts in other colors are left as they are. The watch never deletes or merges a duplicate. |
| Pages | `GET ?after=<cursor>&limit=40` and follow `more`. `limit` is clamped 1–500 by the server. |
| POST | At most 40 items per POST (server cap 100). |
| Refill (§5.6 step 3) | **Watch exception, agreed with Forge.** After an epoch change or `seq` going back, the watch resets its cursor and re-pushes only its own records: the highlight records of verses in its Bookmarks color, that color record, and any unsent local edits. It never stores notes, `x-` kinds, other colors' records or old tombstones, so phones and the web refill those. |

## Verified

- Unit tests: tie-break, duplicate-color choice, id-mismatch skip, padding, SPEC §10 vector through `openItem`.
- Simulator round trips against a throwaway library: push, pull, remove (tombstone),
  paging with `limit=2` (6 items in 3 pages), and switching to an older duplicate color.
