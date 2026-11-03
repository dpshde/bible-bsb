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
| Pages | `GET ?after=<cursor>&limit=30` (about 13 KB of typical items) and follow `more`. On -402/-403 the watch halves `limit` for the rest of the sync. If even `limit=1` is too big, the first item after the cursor is one big item, so the watch steps the cursor past it (at most 25 steps per sync). |
| POST | At most 20 items per POST (server cap 100), halved on -102 (request too large). |
| Pacing | Decryption is budgeted at two 256-byte blocks per 50 ms tick, and record edits at 2 per tick. Items over 512 bytes of plaintext (long notes) are passed over without decrypting. The rescan uses a ref → colors index instead of re-parsing records. |
| Refill (§5.6 step 3) | **Watch exception, agreed with Forge.** After an epoch change or `seq` going back, the watch resets its cursor and re-pushes only its own records: the highlight records of verses in its Bookmarks color, that color record, and any unsent local edits. It never stores notes, `x-` kinds, other colors' records or old tombstones, so phones and the web refill those. |

## Verified

- Unit tests: tie-break, duplicate-color choice, id-mismatch skip, padding, SPEC §10 vector through `openItem`.
- Simulator round trips against a throwaway library: push, pull, remove (tombstone),
  paging with `limit=2` (6 items in 3 pages), and switching to an older duplicate color.

## Verification 2026-11-03

All checks ran against hidden-word.dpshade.workers.dev (Worker 7e0a5a6f, with `limit`), writing only
to the throwaway library. Scripts are outside the repo: `/workspace/labs/hw-verify/{probe,seed,view,health,bytes}.mjs`.

**Server**

| Check | Result |
| --- | --- |
| `limit` 1, 2, 500 | 1, 2 and all items. `more` is correct. |
| `limit` 0, -1, 1.5 | Clamped/truncated to 1 (200). |
| `limit` 501 | Clamped to 500 (200). |
| `limit` abc, empty, missing | Default 500 (200). |
| Cursor walk at limit=1 and 3 | Same seqs as one full page, strictly increasing, no gaps or duplicates. |
| `after` = head, head+1, 999999999 | 200, no items, `more:false`, `seq` = head. |
| `after` = -1 or x | 400 "after must be a non-negative integer". |
| Page bytes, realistic items (379-char blobs) | About 431 B per item. limit=20: 8,666 B; 30: 12,966 B; 36: 15,546 B; 40: 17,266 B. Responses are brotli on the wire, but the watch's limit applies to the decoded body. |
| POST 101 items / 0 items | 400 "at most 100 items per request" / 400 "items must be a non-empty list". |
| Blob of 378 or 21,901 chars | 400 "blob size out of range". |
| Bad id, non-JSON body, 2.5 MB body | 400, 400, 413. |
| Missing, malformed, `Basic` or wrong Bearer token (GET and POST) | 401 with only `{"error":…}`. No item data. |
| Two clients write one record concurrently with equal `updated` | Both clients and the server converge on the version whose text is larger as UTF-8 bytes. |
| Health: GET lib and `/` every 30 s for 5 min (11 each) | All 200. lib p50 179 ms / p95 320 ms; `/` p50 70 ms / p95 142 ms. |

**Watch (Enduro 3 simulator)**

| Run | Result |
| --- | --- |
| Fresh watch, 60-record library (45 yellow/green highlights, 2 notes incl. a ~21 KB one, x- kind, 3 Bookmarks colors) | 4.3 s: 7 pages, 59 pulled, 2 big items passed over, Bookmarks color `c-0alpha`. |
| Paging test build, `limit=2` | 28 pages, 55 items, 7.4 s, no gaps. |
| Range bookmarked on the watch | 3 pushed, 645 ms. |
| Verse added on the reference client | Watch adds the bookmark, 486 ms. |
| Bookmark removed on the watch | Deletion pushed, 494 ms. |
| Verses deleted on the reference client | Watch drops them (−3). |
| Third duplicate color (same `created` as `c-0older`, lower ref `c-0alpha`) plus mixed records | The watch switched to `c-0alpha` and added parts. All three colors are still live, the other colors' parts (yellow, `c-0older`, `c-ba9f60`) were kept, and nothing was deleted. The watch's view (color + verses) matches sync.js under the same pick rule. |
| Response size limit | The simulator answers -402 between 15,546 B (ok) and 17,266 B (fails), so roughly 16 KB. `limit=40` failed, so the default is now 30. The halving and cursor-step fallback handled a ~21 KB single note. |

**Bugs found and fixed in this pass**
- A 2 KB note tripped the watchdog while it was being decrypted (one GCM over 8 blocks). Fixed with the block budget and by passing over items larger than 2 blocks.
- `rescan()` re-parsed every stored record in one event and tripped the watchdog once the library had about 50 highlights. It now uses the ref → colors index.
- `diff()` edited 4 or more records in one event and tripped the watchdog after a color switch. Edits are now paced. The crashed sync recovered on the next start without losing data.
- Unit tests share the simulator app's storage and wipe its bookmarks. Reset the simulator after a test run before doing a round trip.

**Not verified / open**
- Refill after an epoch change or `seq` going back. That needs a DELETE of the throwaway library, which needs Dylan's yes. The code path is reviewed only.
- Real watch hardware: the actual -402 limit (forum reports range from about 8 KB to 44 KB by model) and -102 on POST. Both fall back by halving, but neither has been seen on a device.
- Pacing of `refill()` (one HMAC per bookmarked verse in one event) and `applyDelta` for very large bookmark sets has not been stress-tested.
- A highlight record with more than 512 bytes of plaintext (several parts with quotes) is passed over. If one carries a Bookmarks part, the watch misses that bookmark.
- Every fresh sync starts at `limit=30` again, so a library with a long note early on spends a few -402 round trips (about 1 s) before it gets past it.

**Suggestions for the server (Forge), none blocking**
- A byte budget per page (for example `maxBytes=`, or stop the page before it exceeds N bytes) would let small clients skip the halving and cursor steps.
- `limit` quietly falls back to 500 for non-numeric values but clamps -1 and 0 to 1, while `after=-1` is a 400. That's harmless, but inconsistent.
- 401 says "wrong token for this library" for a claimed library and "missing or malformed" otherwise, and an unclaimed library answers 200 with an empty list. Together these reveal whether a library id exists. Ids are 128-bit, so the risk is low.

## Sync status (0.9.1)

The watch writes a one-line result to the read-only **Sync status** setting (`hwStatus`) at the
end of every sync, on every failure and on a key problem, so it shows in Garmin Connect the next
time the phone reads the app's settings. The Bookmarks list on the watch ends with a **Sync now**
row whose sublabel is the short form (`ok 1:58 PM`, `error -104`, `no Bookmarks color`); selecting
it syncs. The line never contains the key. Writing it never starts a sync: `onSettingsChanged`
ignores a change that leaves server, key and switch as they were within 10 s of the last status
write, and settings changed mid-sync apply once that sync ends.

| Situation | Status line |
| --- | --- |
| Before the first sync | `Not synced yet: open the app on the watch` (default) |
| Switch off / no key / bad key | `sync off` / `no key: paste the sync key from Hidden Word` / `key typo: check the sync key (XXXX-XXXX-...)` |
| In progress (sync runs only while the app is open) | `syncing 1:58 PM: 30 items read, keep the app open` |
| Phone / Bluetooth / Connect IQ | `error -104 (phone not connected) 1:58 PM`; also -101 busy, -2/-3 link timed out, -300 phone offline, -400/-1002 not JSON (server URL), -402/-403 too big |
| Server | `error 401 (sync key not accepted) ...`, `error 404 (not found: check server URL) ...`, 5xx `server error` |
| Server reached, library empty | `ok 1:58 PM: server has no items for this key (empty library?)` |
| Items, no color named exactly `Bookmarks` | `ok 1:58 PM: no color named 'Bookmarks': 'bookmarks' must be exactly 'Bookmarks' (214 highlights, 6 named colors; read 30, sent 0)` |
| Color exists, no verses in it | `ok 1:58 PM: 'Bookmarks' color has 0 verses (...)` |
| Normal | `ok 1:58 PM: 4 verses in 'Bookmarks', 2 watch bookmarks (52 highlights, 3 named colors; read 59, sent 0)` |
| Exception in a sync step | `error 1:58 PM: <message>` (caught instead of crashing the app) |

**Bugs found and fixed (why a real watch could show no bookmarks)**
- All records lived in one Storage value (`hwRecs`). Storage caps a value at 32 KB, and on the
  Enduro 3 simulator saving one dict of 250 realistic highlight records fails with an
  uncatchable Out Of Memory error (200 is fine). A library with more than ~220 highlights
  crashed every sync partway through the first pull, and the Bookmarks color is only chosen
  after a complete pull, so the watch never showed a bookmark. Records are now in 16 shards
  (`hwR0`..`hwR15`, ~3,000 records); 0.9.0's `hwRecs` moves over on first use.
- A key changed while the app was closed (`onSettingsChanged` doesn't run then) kept the old
  library's cursor and records. The watch now stores the library id (`hwLib`) and starts over
  when it differs (0.9.0 state is kept when its records HMAC back under the current key).
- Settings changed mid-sync swapped keys under the running sync. They now apply when it ends.
- Not bugs, checked: settings set while the app was closed are picked up when it opens
  (`getInitialView` starts a sync); verses in the Bookmarks color are written into the watch's
  own bookmark list (the list shows them, e.g. Romans 5:3-5 from the server); the color name
  match is exact and case-sensitive (SPEC 1.2), which the status line now points out.
- Still open: the ref -> colors index (`hwIdx`) is one Storage value (~800+ highlights); sync
  runs only while the app is open (no background sync).

Simulator checks (Enduro 3, throwaway library; unit tests 80/80):
`ok 7:08 PM: 4 verses in 'Bookmarks', 2 watch bookmarks (52 highlights, 3 named colors; read 59, sent 0)`;
bad server URL: `error -400 (response not JSON: check server URL) 7:08 PM`;
fresh random key: `ok 7:17 PM: server has no items for this key (empty library?)` (times UTC).
