#!/usr/bin/env bash
# mobile.config.sh — Cấu hình mobile-ci cho project K Screens
# Được tạo bởi: mobile-ci init

# ── Thông tin App ────────────────────────────────────────────────────────────
APP_NAME="V Drama"
APP_ID="ai.vdrama.app"
APP_VERSION="${APP_VERSION:-1.0.1}"

# ── Capacitor ────────────────────────────────────────────────────────────────
PLATFORMS="${CAP_PLATFORMS:-ios android}"
WEB_DIR="dist"
BUILD_CMD=""

# Domains cho phép trong WebView
CAP_ALLOW_NAVIGATION="*.youtube.com,*.googleapis.com,*.google.com,*.ailive.kr"

# UI
CAP_SPLASH_BG="#09090b"
CAP_STATUS_BAR_STYLE="Dark"
CAP_STATUS_BAR_BG="#09090b"

# ── Source code paths ────────────────────────────────────────────────────────
# LƯU Ý: Để trống → mobile-ci tự resolve từ PROJECT_ROOT sau khi được set.
# Nếu cấu trúc project khác chuẩn, điền đường dẫn TUYỆT ĐỐI ở đây.
# Ví dụ: APP_JSX_PATH="/home/runner/work/repo/src/main/App.tsx"
APP_JSX_PATH=""
VITE_CONFIG_PATH=""
INDEX_HTML_PATH=""

# Scripts sandbox cần xóa khỏi index.html
SANDBOX_SCRIPT_DOMAINS="dev-cdn.vibe-x.app"

# ── iOS ──────────────────────────────────────────────────────────────────────
IOS_SCHEME="App"
BUILD_CONFIG="Release"

# ── Fastlane ─────────────────────────────────────────────────────────────────
SKIP_FASTLANE="${SKIP_FASTLANE:-false}"
FL_APP_LANGUAGE="ko"
FL_APP_SKU=""
