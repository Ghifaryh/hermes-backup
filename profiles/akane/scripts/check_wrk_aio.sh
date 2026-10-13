#!/usr/bin/env bash
STATUS_FILE="/home/gip/.hermes/profiles/akane/cache/scratch/tailscale_wrk_aio.state"
mkdir -p "$(dirname "$STATUS_FILE")"

# Check status of gip-wrk-aio via tailscale CLI
OUTPUT=$(tailscale status 2>&1 | grep "gip-wrk-aio" || true)

if echo "$OUTPUT" | grep -qi "offline"; then
    CURRENT="offline"
elif [ -n "$OUTPUT" ]; then
    CURRENT="online"
else
    CURRENT="unknown"
fi

PREV="online"
if [ -f "$STATUS_FILE" ]; then
    PREV=$(cat "$STATUS_FILE")
fi

echo "$CURRENT" > "$STATUS_FILE"

# Only alert on transition to offline or if state changed
if [ "$CURRENT" = "offline" ] && [ "$PREV" != "offline" ]; then
    echo "⚠️ Alert: Tailscale peer \`gip-wrk-aio\` has gone OFFLINE."
elif [ "$CURRENT" = "online" ] && [ "$PREV" = "offline" ]; then
    echo "✅ Notice: Tailscale peer \`gip-wrk-aio\` is back ONLINE."
fi
