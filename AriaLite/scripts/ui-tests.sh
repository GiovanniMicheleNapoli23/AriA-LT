#!/bin/bash
#
#  ui-tests.sh
#  AriaLite
#
#  Created by Giovanni Michele on 21/10/26.
#
#  Prepara e lancia i test UI contro il backend vero. La sessione di un operatore si ottiene con il link
#  via email (una volta sola, vale 15 minuti) e si salva in ~/.aria-uitest-session (fuori dal repository,
#  permessi 600): dura circa 7 giorni, poi si rifà `request` + `login`.
#
#      scripts/ui-tests.sh request operatore@azienda.it   # manda il link di accesso all'email
#      scripts/ui-tests.sh login '<link o token>'         # scambia il link con la sessione e la salva
#      scripts/ui-tests.sh test                           # solo letture
#      scripts/ui-tests.sh test --write                   # anche i test che scrivono (closeout, fatti)
#
#  Variabili opzionali: DEST (destinazione xcodebuild; default il primo iPhone avviato), AUTH_HOST.
#

set -euo pipefail

AUTH_HOST="${AUTH_HOST:-https://app.ariaplt.com}"
SESSION_FILE="$HOME/.aria-uitest-session"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
request)
    email="${2:?uso: ui-tests.sh request <email-operatore>}"
    status=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$AUTH_HOST/api/auth/mobile/request-link" \
        -H 'Content-Type: application/json' -d "{\"email\":\"$email\"}")
    echo "request-link: HTTP $status (202 anche per un indirizzo che non è di un operatore)"
    echo "Apri l'email e lancia: scripts/ui-tests.sh login '<link>'"
    ;;
login)
    raw="${2:?uso: ui-tests.sh login <link-o-token>}"
    token=$(printf '%s' "$raw" | sed -E 's/.*token=//; s/[&#].*//')
    reply=$(curl -si -X POST "$AUTH_HOST/api/auth/mobile/verify" \
        -H 'Content-Type: application/json' -d "{\"token\":\"$token\"}")
    status=$(printf '%s' "$reply" | head -1 | awk '{print $2}')
    session=$(printf '%s' "$reply" | tr -d '\r' | awk 'tolower($1)=="set-auth-token:" {print $2}')
    if [ "$status" != "200" ] || [ -z "$session" ]; then
        echo "verify: HTTP $status, nessuna sessione. Il link è scaduto, già usato o non è di un operatore." >&2
        exit 1
    fi
    umask 077
    printf '%s' "$session" > "$SESSION_FILE"
    echo "Sessione salvata in $SESSION_FILE. Ora: scripts/ui-tests.sh test"
    ;;
test)
    [ -s "$SESSION_FILE" ] || { echo "Nessuna sessione: scripts/ui-tests.sh request <email>, poi login." >&2; exit 1; }
    export TEST_RUNNER_ARIA_LIVE_SESSION="$(cat "$SESSION_FILE")"
    [ "${2:-}" = "--write" ] && export TEST_RUNNER_ARIA_LIVE_WRITE=1
    dest="${DEST:-}"
    if [ -z "$dest" ]; then
        id=$(xcrun simctl list devices booted | grep -m1 iPhone | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
        [ -n "$id" ] || { echo "Nessun iPhone avviato: apri un simulatore o imposta DEST." >&2; exit 1; }
        dest="platform=iOS Simulator,id=$id"
    fi
    log="$(mktemp -t aria-ui-tests).log"
    echo "Log completo: $log"
    cd "$ROOT"
    # Senza CODE_SIGNING_ALLOWED=NO: il Keychain dell'app non funzionerebbe.
    xcodebuild test -project AriaLite.xcodeproj -scheme AriaLite -destination "$dest" \
        -only-testing:AriaLiteUITests > "$log" 2>&1 || true
    grep -E "Test Case .*(passed|failed|skipped)|Executed [0-9]+ tests|error:|TEST (SUCCEEDED|FAILED)|\*\* TEST" "$log" | tail -40
    ;;
*)
    sed -n 9,20p "$0"
    exit 1
    ;;
esac
