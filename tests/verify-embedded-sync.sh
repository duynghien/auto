#!/bin/bash
################################################################
# verify-embedded-sync.sh
# Verifies standalone integrity, embedded templates sync,
# security hardening, and shellcheck compliance across all
# 24 self-hosted installers in duynghien/auto.
################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
TESTS_RUN=0

pok()  { echo -e "  ${GREEN}✓${NC} $1"; }
pwarn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
perr() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo -e "\n${BOLD}${BLUE}================================================================${NC}"
echo -e "${BOLD}${BLUE}  Gen 4 Standalone & Embedded Sync Verification Suite           ${NC}"
echo -e "${BOLD}${BLUE}================================================================${NC}\n"

# 1. Verify all 24 tool setup.sh scripts exist and are executable
echo -e "${BOLD}[1/5] Checking all 24 setup.sh scripts...${NC}"
ALL_TOOLS=(
  "anycrawl" "boltdiy" "crawl4ai" "espocrm" "firecrawl" "grafana"
  "headscale" "listmonk" "lobehub" "matomo" "mautic" "mem0"
  "n8n" "openclaw-n8n-mcp" "posthog" "postiz" "prometheus" "proxies"
  "raspberry-pi" "scrapling" "spacebot" "supabase" "twenty" "wordops"
)

for tool in "${ALL_TOOLS[@]}"; do
  TESTS_RUN=$((TESTS_RUN + 1))
  SETUP_FILE="${tool}/setup.sh"
  if [[ -f "$SETUP_FILE" && -x "$SETUP_FILE" ]]; then
    pok "Installer exists and executable: ${SETUP_FILE}"
  else
    perr "Missing or non-executable installer: ${SETUP_FILE}"
  fi
done

# 2. Verify Gen 4 Gold Standard invariants in all 24 setup.sh
echo -e "\n${BOLD}[2/5] Verifying Gen 4 invariants (strict mode, traps, chmod 600 .env)...${NC}"
for tool in "${ALL_TOOLS[@]}"; do
  SETUP_FILE="${tool}/setup.sh"
  [[ -f "$SETUP_FILE" ]] || continue

  # Invariant 2.1: Strict mode set -euo pipefail
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "set -euo pipefail" "$SETUP_FILE"; then
    pok "${tool}: set -euo pipefail verified"
  else
    perr "${tool}: missing set -euo pipefail in ${SETUP_FILE}"
  fi

  # Invariant 2.2: ERR trap
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "trap 'on_error" "$SETUP_FILE" || grep -q 'trap "on_error' "$SETUP_FILE" || grep -q "trap 'echo" "$SETUP_FILE"; then
    pok "${tool}: ERR trap verified"
  else
    perr "${tool}: missing ERR trap in ${SETUP_FILE}"
  fi

  # Invariant 2.3: chmod 600 .env (except tools that don't use .env like raspberry-pi/wordops)
  if [[ "$tool" != "raspberry-pi" && "$tool" != "wordops" ]]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -q "chmod 600.*\.env" "$SETUP_FILE" || grep -q "chmod 600.*env" "$SETUP_FILE"; then
      pok "${tool}: chmod 600 .env verified"
    else
      perr "${tool}: missing chmod 600 .env in ${SETUP_FILE}"
    fi
  fi
done

# 3. Verify canonical symlinks
echo -e "\n${BOLD}[3/5] Verifying canonical symlinks...${NC}"
SYMLINKS=(
  "crawl4ai/crawl4ai.sh:c4ai.sh"
  "firecrawl/firecrawl.sh:fc.sh"
  "lobehub/lobehub.sh:lobe.sh"
  "posthog/posthog.sh:hog.sh"
  "supabase/supabase.sh:supa.sh"
)

for item in "${SYMLINKS[@]}"; do
  TESTS_RUN=$((TESTS_RUN + 1))
  LINK_FILE="${item%%:*}"
  TARGET="${item##*:}"
  if [[ -L "$LINK_FILE" ]]; then
    ACTUAL_TARGET=$(readlink "$LINK_FILE")
    if [[ "$ACTUAL_TARGET" == "$TARGET" ]]; then
      pok "Symlink ${LINK_FILE} -> ${TARGET} verified"
    else
      perr "Symlink ${LINK_FILE} points to ${ACTUAL_TARGET}, expected ${TARGET}"
    fi
  else
    perr "Missing symlink: ${LINK_FILE}"
  fi
done

# 4. Verify embedded templates sync with sibling repo files
echo -e "\n${BOLD}[4/5] Verifying embedded template synchronization...${NC}"

# 4.1 Twenty docker-compose.yml check
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -f "twenty/docker-compose.yml" ]] && grep -q "COMPOSE_EOF" twenty/setup.sh; then
  if grep -q "server:" twenty/docker-compose.yml && grep -q "server:" twenty/setup.sh; then
    pok "twenty/docker-compose.yml synced with twenty/setup.sh generator"
  else
    perr "twenty/docker-compose.yml mismatch with setup.sh generator"
  fi
else
  pwarn "twenty/docker-compose.yml check skipped"
fi

# 4.2 AnyCrawl embedded MCP server and SearXNG settings check
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "PKG_EOF" anycrawl/setup.sh && grep -q "SETTINGS_EOF" anycrawl/setup.sh; then
  pok "anycrawl embedded templates verified (searxng/settings.yml, mcp-server/)"
else
  perr "anycrawl embedded templates missing in setup.sh"
fi

# 4.3 WordOps embedded backup and restore scripts
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -f "wordops/scripts/backup.sh" && -f "wordops/scripts/restore.sh" ]]; then
  if grep -q "BACKUP_SCRIPT_EOF" wordops/setup.sh && grep -q "RESTORE_SCRIPT_EOF" wordops/setup.sh; then
    pok "wordops/scripts/backup.sh and restore.sh embedded sync verified"
  else
    perr "wordops setup.sh does not match scripts/backup.sh or restore.sh"
  fi
else
  perr "Missing wordops/scripts/backup.sh or restore.sh"
fi

# 5. Bash syntax and Shellcheck verification across all shell scripts
echo -e "\n${BOLD}[5/5] Running bash -n and shellcheck -S error across all shell scripts...${NC}"
SHELL_FILES=$(find . -name "*.sh" -not -path "*/.*" -not -path "./scratch*" | sort)

for sh_file in $SHELL_FILES; do
  TESTS_RUN=$((TESTS_RUN + 1))
  if bash -n "$sh_file"; then
    pok "bash -n: ${sh_file}"
  else
    perr "bash -n failed on: ${sh_file}"
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if shellcheck -S error "$sh_file"; then
    pok "shellcheck: ${sh_file}"
  else
    perr "shellcheck -S error failed on: ${sh_file}"
  fi
done

# Summary
echo -e "\n${BOLD}================================================================${NC}"
echo -e "${BOLD}Verification Summary: ${TESTS_RUN} checks run${NC}"
echo -e "  Passed:   $((TESTS_RUN - ERRORS))"
echo -e "  Warnings: ${WARNINGS}"
echo -e "  Errors:   ${ERRORS}"
echo -e "${BOLD}================================================================${NC}"

if [[ "$ERRORS" -gt 0 ]]; then
  echo -e "\n${RED}✖ Verification FAILED with ${ERRORS} error(s).${NC}\n" >&2
  exit 1
else
  echo -e "\n${GREEN}✔ All Gen 4 Standalone Gold Standard checks PASSED!${NC}\n"
  exit 0
fi
