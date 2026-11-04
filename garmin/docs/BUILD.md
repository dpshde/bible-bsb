# Build, test, export

Needs the Connect IQ SDK (9.x) with device packs (`connect-iq-sdk-manager login`, then
`device download -m garmin/manifest.xml`) and a developer key. Keys, `bin/`, `*.prg`, `*.iq` and
`tmp-personal/` are gitignored; never commit them.

```sh
# Developer key (once)
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

cd garmin

# Debug build for the simulator
monkeyc -f monkey.jungle -d enduro3_sim -o bin/bsb-enduro3.prg -y ../developer_key.der -w
connectiq &                      # simulator
monkeydo bin/bsb-enduro3.prg enduro3

# Unit tests (repeat for fr265). monkeydo exits non-zero even when all tests pass: read the
# "PASSED (passed=N, failed=0, errors=0)" line.
monkeyc -f monkey.jungle -d enduro3_sim -o bin/bsb-test.prg -y ../developer_key.der --unit-test -w
monkeydo bin/bsb-test.prg enduro3 -t

# Release sideload build
monkeyc -r -w -f monkey.jungle -d enduro3 -o bin/BibleBSB-enduro3.prg -y ../developer_key.der

# Store package (all manifest products). Connect IQ manifests carry no version: enter it
# (e.g. 0.9.9) on the upload form. The app id in manifest.xml must be the listing's id.
monkeyc -e -r -w -f monkey.jungle -o bin/BibleBSB.iq -y ../developer_key.der
```

## Personal build with a sync key

The store build has no key (`PersonalSyncStub.mc`, annotation `keystub`). For your own watch:

```sh
SELAH_VAULT_SYNC_KEY=... tools/make_personal_sync.sh          # -> tmp-personal/src (gitignored)
monkeyc -r -w -f "monkey.jungle;tmp-personal/src/personal.jungle" -d enduro3 \
  -o tmp-personal/BIBLEBSB.PRG -y ../developer_key.der
```

The script never prints the key and writes the file mode 600.

## Screenshots

See `docs/screens/capture-screens.md`.
