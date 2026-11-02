# Build & simulator notes

## What this cloud agent did

| Step | Result |
|------|--------|
| Accept CIQ SDK license via `connect-iq-sdk-manager agreement accept` | OK |
| Download SDK 9.3.0 (`sdk set ">=7.0.0"`) | OK → `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.3.0-…` |
| `device download -d enduro3` (and budget devices) | **BLOCKED** — requires `connect-iq-sdk-manager login` (Garmin SSO). No `GARMIN_USERNAME` / password in this environment. |
| `monkeyc -d enduro3 …` | **Fails:** `ERROR: Invalid device id specified: 'enduro3'.` (exit 101) — no `~/.Garmin/ConnectIQ/Devices/` tree until login + `device download` |
| Simulator screenshots under xvfb | **Not captured** — no device profiles → no sim targets. Never faked. |

CLI used: [lindell/connect-iq-sdk-manager-cli](https://github.com/lindell/connect-iq-sdk-manager-cli) v0.8.4 Linux x86_64 (also works via official SDK Manager GUI).

## Commands Dylan should run on his Mac

```sh
# 1) SDK Manager (GUI) from https://developer.garmin.com/connect-iq/sdk/
#    — or CLI:
curl -sL -o ciq-cli.tgz \
  https://github.com/lindell/connect-iq-sdk-manager-cli/releases/download/v0.8.4/connect-iq-sdk-manager-cli_0.8.4_Darwin_ARM64.tar.gz
tar xzf ciq-cli.tgz
./connect-iq-sdk-manager agreement accept
./connect-iq-sdk-manager login          # browser SSO
./connect-iq-sdk-manager sdk set ">=9.0.0"
./connect-iq-sdk-manager device download -m garmin/manifest.xml -F

export PATH="$(./connect-iq-sdk-manager sdk current-path --bin):$PATH"

# 2) Developer key (once)
openssl genrsa -out garmin/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in garmin/developer_key.pem -out garmin/developer_key.der -nocrypt

# 3) Build
cd garmin
monkeyc -f monkey.jungle -d enduro3 -o bin/bsb-enduro3.prg -y developer_key.der -w
monkeyc -f monkey.jungle -d fr265 -o bin/bsb-fr265.prg -y developer_key.der -w

# 4) Tests
monkeyc -f monkey.jungle -d enduro3 -o bin/bsb-test.prg -y developer_key.der -t -w
connectiq &   # start sim
monkeydo bin/bsb-test.prg enduro3 -t

# 5) Screenshots → garmin/docs/screens/<device>/<state>.png
#    Follow PLAN.md capture steps (M4–M8). Use sim Screenshot or:
#    screencapture / Monkey Motion as you prefer.
```

Linux VM (after login):

```sh
export PATH="$HOME/.Garmin/ConnectIQ/Sdks/$(cat $HOME/.Garmin/ConnectIQ/current-sdk.cfg)/bin:$PATH"
# device download still needs login first
xvfb-run -a connectiq &
# then monkeydo …
```

## Screenshot gap log

See `docs/screens/MISSING.md` (updated when captures fail).
