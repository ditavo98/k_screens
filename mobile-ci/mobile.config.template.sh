#!/usr/bin/env bash
# mobile.config.sh — Cấu hình project cho mobile-ci service
#
# Cách dùng:
#   1. Sao chép file này vào thư mục gốc của project
#   2. Điền các giá trị bên dưới
#   3. Chạy: mobile-ci setup (hoặc bash path/to/mobile-ci/bin/mobile-ci setup)
#
# File này được source bởi mobile-ci, KHÔNG chạy trực tiếp.
# ============================================================================

# ── Thông tin App ────────────────────────────────────────────────────────────
APP_NAME="My App"                        # Tên app hiển thị trên store
APP_ID="com.example.myapp"               # Bundle ID / Application ID
APP_VERSION="${APP_VERSION:-1.0.0}"      # Phiên bản (có thể override từ CI)

# ── Capacitor ────────────────────────────────────────────────────────────────
# Platforms cần add: "ios", "android", hoặc "ios android"
PLATFORMS="ios android"

# Thư mục output của build (vite → dist, CRA → build)
WEB_DIR="dist"

# Custom build command (để trống → tự detect từ package manager)
BUILD_CMD=""

# Cho phép navigate đến các domain này trong WebView
# Phân cách bằng dấu phẩy, ví dụ: "*.googleapis.com,*.youtube.com"
CAP_ALLOW_NAVIGATION=""

# Màu splash screen (hex)
CAP_SPLASH_BG="#ffffff"

# Status bar: Default | Dark | Light
CAP_STATUS_BAR_STYLE="Default"
CAP_STATUS_BAR_BG="#ffffff"

# ── Source code paths (để trống → dùng giá trị mặc định) ────────────────────
# LƯU Ý: ${PROJECT_ROOT} chưa được set khi file này được source.
# Để trống để mobile-ci tự detect, hoặc dùng đường dẫn TUYỆT ĐỐI.
# Đường dẫn đến file router chính (mặc định: src/App.jsx)
APP_JSX_PATH=""                          # ví dụ: "/path/to/project/src/main/App.tsx"

# Đường dẫn đến vite.config (mặc định: vite.config.js)
VITE_CONFIG_PATH=""                      # ví dụ: "/path/to/project/vite.config.ts"

# Đường dẫn đến index.html (mặc định: index.html)
INDEX_HTML_PATH=""

# ── Sandbox scripts cần xóa khỏi index.html ─────────────────────────────────
# Phân cách bằng | nếu có nhiều domain
# Ví dụ: "dev-cdn.vibe-x.app|sandbox.other-platform.com"
SANDBOX_SCRIPT_DOMAINS="dev-cdn.vibe-x.app"

# ── iOS ──────────────────────────────────────────────────────────────────────
IOS_SCHEME="App"
BUILD_CONFIG="Release"

# ── Fastlane ─────────────────────────────────────────────────────────────────
# Đặt true để bỏ qua toàn bộ Fastlane setup
SKIP_FASTLANE="false"

# Ngôn ngữ chính của app trên App Store (vi, en-US, ko, ja, ...)
FL_APP_LANGUAGE="en-US"

# SKU trên App Store Connect (để trống → tự tạo từ APP_ID)
FL_APP_SKU=""
