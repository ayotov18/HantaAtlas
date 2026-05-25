#!/usr/bin/env bash
# block-dangerous-bash.sh — preToolUse hook for Bash invocations.
#
# Claude Code passes the tool input JSON on stdin. We grep the `command`
# field for irreversibly destructive patterns and exit non-zero to block.
# Non-zero exit prevents the tool from running and surfaces the message
# to Claude (which then explains it to the user and picks a safer path).
#
# Patterns blocked here are ones the .claude/settings.json deny list
# already catches at the schema level, but a shell pre-filter is a
# belt-and-braces layer in case settings get tampered with locally.
#
# To add a pattern: drop it in the case statement below. Keep the list
# tight — over-blocking trains Claude (and humans) to disable the hook.

set -euo pipefail

input="$(cat)"

# Extract the `command` field from the JSON payload. jq if available,
# otherwise a tolerant grep fallback so the hook still works on a fresh
# clone where jq might not be installed.
if command -v jq >/dev/null 2>&1; then
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
    cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
fi

case "$cmd" in
    *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*)
        echo "blocked: refused to delete a system root or home directory" >&2
        exit 2
        ;;
    *"git push --force"*|*"git push -f "*|*"git push --force-with-lease origin main"*|*"git push --force-with-lease origin master"*)
        echo "blocked: refused to force-push. Investigate the divergence first; rewriting shared history can lose other people's work." >&2
        exit 2
        ;;
    *"--no-verify"*|*"--no-gpg-sign"*)
        echo "blocked: refused to skip git hooks or signing. If a hook is failing, fix the root cause; don't bypass it." >&2
        exit 2
        ;;
    *"DROP DATABASE"*|*"DROP TABLE"*|*"TRUNCATE"*)
        echo "blocked: refused to run destructive SQL. If this is intentional, run it manually with a clear backup path." >&2
        exit 2
        ;;
    *)
        exit 0
        ;;
esac
