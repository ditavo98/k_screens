#!/usr/bin/env bash
# lib/00_colors.sh — Màu sắc và logging functions dùng chung

# Tắt màu khi không có TTY (pipe, CI không hỗ trợ) hoặc NO_COLOR được set
# Tham chiếu: https://no-color.org
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  CYAN=$'\033[0;36m'
  BLUE=$'\033[0;34m'
  MAGENTA=$'\033[0;35m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BLUE=''
  MAGENTA=''
  BOLD=''
  DIM=''
  RESET=''
fi

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_skip()    { echo -e "${DIM}[SKIP]  $*${RESET}"; }
log_section() {
  echo ""
  echo -e "${BOLD}${BLUE}┌──────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${BLUE}│  $*${RESET}"
  echo -e "${BOLD}${BLUE}└──────────────────────────────────────────┘${RESET}"
}
log_header() {
  echo ""
  echo -e "${BOLD}${MAGENTA}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${MAGENTA}║  $*${RESET}"
  echo -e "${BOLD}${MAGENTA}╚══════════════════════════════════════════╝${RESET}"
  echo ""
}
