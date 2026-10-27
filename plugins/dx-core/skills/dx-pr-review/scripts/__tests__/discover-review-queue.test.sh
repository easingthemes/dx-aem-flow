#!/usr/bin/env bash
# discover-review-queue.sh selection rules: queue a PR only when a
# REVIEWER_IDENTITIES identity is an assigned reviewer with vote 0 AND that
# identity has not posted an "[AI Review]" comment since the PR's last push.
#
# Hermetic: `curl` is a PATH stub that serves fixture JSON by URL, so no ADO
# and no network. SCRIPT overrides the script under test (used to prove the
# re-review cases fail on the pre-fix script).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${SCRIPT:-$HERE/../discover-review-queue.sh}"
FAIL=0; PASS=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fx"

# Stub: map the URL to a fixture file; a missing fixture is an HTTP failure.
cat > "$T/bin/curl" <<'EOF'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  */pullrequests\?*)                    f=list ;;
  */pullRequests/*/iterations\?*)       id=${url%/iterations*}; f="iter-${id##*/}" ;;
  */pullRequests/*/threads\?*)          id=${url%/threads*};    f="threads-${id##*/}" ;;
  *) exit 22 ;;
esac
[ -f "$FX/$f.json" ] || exit 22
cat "$FX/$f.json"
EOF
chmod +x "$T/bin/curl"

BOT='{"uniqueName":"bot@x.com","displayName":"Bot"}'
HUMAN='{"uniqueName":"dev@x.com","displayName":"Dev"}'
pr() { # id vote
  printf '{"pullRequestId":%s,"createdBy":%s,"reviewers":[{"uniqueName":"bot@x.com","displayName":"Bot","vote":%s}]}' "$1" "$HUMAN" "$2"
}
iter()    { printf '{"value":[{"id":1,"createdDate":"2026-10-01T10:00:00.1Z"},{"id":2,"createdDate":"%s"}]}' "$1"; }
summary() { # author publishedDate
  printf '{"value":[{"id":9,"comments":[{"author":%s,"content":"**[AI Review] Verdict: changes-requested**","publishedDate":"%s"}]}]}' "$1" "$2"
}

# 101: never reviewed                         → queue
# 102: reviewed after the last push            → skip (the 436737 loop)
# 103: reviewed, then a new push               → queue
# 104: "[AI Review]" text but from a human     → queue
# 105: iterations endpoint fails               → queue (fail-open)
# 106: bot already voted                       → skip (unchanged rule)
# 107: reviewed in the same second as the push, shorter fraction → skip
printf '{"value":[%s,%s,%s,%s,%s,%s,%s]}' "$(pr 101 0)" "$(pr 102 0)" "$(pr 103 0)" \
  "$(pr 104 0)" "$(pr 105 0)" "$(pr 106 10)" "$(pr 107 0)" > "$T/fx/list.json"
for id in 101 102 103 104 106 107; do iter "2026-10-08T00:00:00.5Z" > "$T/fx/iter-$id.json"; done
echo '{"value":[]}'                               > "$T/fx/threads-101.json"
summary "$BOT"   "2026-10-08T00:07:17.39Z"      > "$T/fx/threads-102.json"
summary "$BOT"   "2026-10-07T23:00:00.123456Z"  > "$T/fx/threads-103.json"
summary "$HUMAN" "2026-10-09T00:00:00Z"         > "$T/fx/threads-104.json"
summary "$BOT"   "2026-10-09T00:00:00Z"         > "$T/fx/threads-105.json"
echo '{"value":[]}'                               > "$T/fx/threads-106.json"
summary "$BOT"   "2026-10-08T00:00:00.9Z"       > "$T/fx/threads-107.json"

OUT=$(FX="$T/fx" PATH="$T/bin:$PATH" ADO_PAT=x REVIEWER_IDENTITIES="Bot@x.com" \
      bash "$SCRIPT" "https://dev.azure.com/org/" "My Project" "repo" 2>"$T/err")
RC=$?
[ "$RC" -eq 0 ] && ok "exit 0" || { bad "exit $RC"; cat "$T/err"; }

has()  { grep -q "/pullrequest/$1\$" <<<"$OUT"; }
for id in 101 103 104 105; do has $id && ok "queues PR $id" || bad "PR $id not queued"; done
for id in 102 106 107; do has $id && bad "PR $id queued, should be skipped" || ok "skips PR $id"; done
grep -q '^https://dev.azure.com/org/My%20Project/_git/repo/pullrequest/101$' <<<"$OUT" \
  && ok "URL format unchanged" || bad "URL format: $(head -1 <<<"$OUT")"
grep -q "skip PR 102" "$T/err" && ok "logs skip reason" || bad "no skip log for 102"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
