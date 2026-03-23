#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  JutForm Pre-flight Check"
echo "=========================================="
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "ok" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $name — $3"
        FAIL=$((FAIL + 1))
    fi
}

echo "Checking Docker containers..."
echo ""

# Check all containers are running
for svc in nginx php-fpm mysql redis mailpit; do
    status=$(docker compose ps --format '{{.State}}' "$svc" 2>/dev/null || echo "not found")
    if [ "$status" = "running" ]; then
        check "$svc container" "ok"
    else
        check "$svc container" "fail" "status: $status"
    fi
done

echo ""
echo "Checking service connectivity..."
echo ""

# Hit the health endpoint
HEALTH=$(curl -s -w "\n%{http_code}" http://localhost:8080/api/health 2>/dev/null || echo -e "\n000")
HTTP_CODE=$(echo "$HEALTH" | tail -1)
BODY=$(echo "$HEALTH" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    check "PHP backend (Nginx → PHP-FPM)" "ok"

    # Parse individual checks from JSON
    for svc in mysql redis mailpit; do
        svc_status=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['checks'].get('$svc',{}).get('status','missing'))" 2>/dev/null || echo "parse_error")
        if [ "$svc_status" = "ok" ]; then
            check "PHP → $svc" "ok"
        else
            check "PHP → $svc" "fail" "status: $svc_status"
        fi
    done

    # Check extensions
    ext_issues=$(echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
exts = d['checks'].get('extensions', {})
missing = [k for k, v in exts.items() if v != 'ok']
print(','.join(missing) if missing else 'none')
" 2>/dev/null || echo "parse_error")
    if [ "$ext_issues" = "none" ]; then
        check "PHP extensions" "ok"
    else
        check "PHP extensions" "fail" "missing: $ext_issues"
    fi
else
    check "PHP backend" "fail" "HTTP $HTTP_CODE — is Nginx running?"
fi

# Check Mailpit web UI
MAILPIT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8025/ 2>/dev/null || echo "000")
if [ "$MAILPIT_CODE" = "200" ]; then
    check "Mailpit web UI (:8025)" "ok"
else
    check "Mailpit web UI (:8025)" "fail" "HTTP $MAILPIT_CODE"
fi

# Check frontend
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")
if [ "$FRONTEND_CODE" = "200" ]; then
    check "Frontend served by Nginx (:8080)" "ok"
else
    check "Frontend served by Nginx (:8080)" "fail" "HTTP $FRONTEND_CODE"
fi

echo ""
echo "=========================================="
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}ALL $PASS CHECKS PASSED${NC}"
    echo ""
    echo "  Your environment is ready for the assessment."
    echo "  You can shut it down with: docker compose down"
else
    echo -e "  ${RED}$FAIL CHECK(S) FAILED${NC}, $PASS passed"
    echo ""
    echo "  Please fix the failing checks and re-run:"
    echo "  ./scripts/verify.sh"
fi
echo "=========================================="
echo ""
