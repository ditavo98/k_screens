#!/usr/bin/env bash
# =============================================================================
# add-capacitor.sh
# Thêm Capacitor vào dự án React/Vite và tự động fix các lỗi build mobile phổ biến:
#   1. Router: createBrowserRouter → createHashRouter
#   2. Vite base path: thêm base: './'
#   3. Xóa script sandbox VibEx khỏi index.html
#   4. Thêm meta CSP cho capacitor://localhost
#   5. Cài @capacitor/core, @capacitor/cli, @capacitor/ios, @capacitor/android
#   6. Khởi tạo Capacitor và sync
# =============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------- 
# Màu sắc log
# ----------------------------------------------------------------------------- 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"; \
                echo -e "${BOLD}${CYAN}  $*${RESET}"; \
                echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}"; }

# ----------------------------------------------------------------------------- 
# Cấu hình (override bằng biến môi trường khi cần)
# ----------------------------------------------------------------------------- 
APP_NAME="${CAP_APP_NAME:-K Screens}"
APP_ID="${CAP_APP_ID:-kr.ailive.kscreens}"
WEB_DIR="${CAP_WEB_DIR:-dist}"
BUILD_CMD="${CAP_BUILD_CMD:-}"          # để trống → tự detect
PACKAGE_MANAGER=""                      # tự detect
PLATFORMS="${CAP_PLATFORMS:-}"          # "ios", "android", hoặc "ios android"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_JSX="${PROJECT_ROOT}/src/App.jsx"
VITE_CONFIG="${PROJECT_ROOT}/vite.config.js"
INDEX_HTML="${PROJECT_ROOT}/index.html"
CAP_CONFIG="${PROJECT_ROOT}/capacitor.config.json"
BACKUP_SUFFIX=".cap-backup-$(date +%Y%m%d%H%M%S)"

# ----------------------------------------------------------------------------- 
# Hàm tiện ích
# ----------------------------------------------------------------------------- 

# Backup file trước khi sửa
backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cp "$file" "${file}${BACKUP_SUFFIX}"
    log_info "Backed up: $(basename "$file")${BACKUP_SUFFIX}"
  fi
}

# Kiểm tra lệnh tồn tại
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Yêu cầu lệnh '$1' nhưng không tìm thấy. Vui lòng cài đặt và thử lại."
    exit 1
  fi
}

# Detect package manager
detect_package_manager() {
  if [[ -f "${PROJECT_ROOT}/pnpm-lock.yaml" ]] || \
     [[ -f "${PROJECT_ROOT}/pnpm-workspace.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
  elif [[ -f "${PROJECT_ROOT}/yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
  else
    PACKAGE_MANAGER="npm"
  fi
  log_info "Package manager: ${PACKAGE_MANAGER}"
}

# Cài package
pkg_install() {
  local is_dev="${1:-false}"
  shift
  local pkgs=("$@")
  case "$PACKAGE_MANAGER" in
    pnpm)
      if [[ "$is_dev" == "true" ]]; then
        pnpm add -D "${pkgs[@]}"
      else
        pnpm add "${pkgs[@]}"
      fi
      ;;
    yarn)
      if [[ "$is_dev" == "true" ]]; then
        yarn add --dev "${pkgs[@]}"
      else
        yarn add "${pkgs[@]}"
      fi
      ;;
    *)
      if [[ "$is_dev" == "true" ]]; then
        npm install --save-dev "${pkgs[@]}"
      else
        npm install --save "${pkgs[@]}"
      fi
      ;;
  esac
}

# Chạy script npm (npx)
run_npx() {
  npx "$@"
}

# Python / node inline sed-safe replace (dùng node vì macOS sed khác GNU sed)
node_replace() {
  # node_replace <file> <search_regex> <replacement>
  local file="$1"
  local search="$2"
  local replace="$3"
  node -e "
    const fs = require('fs');
    let content = fs.readFileSync('${file}', 'utf8');
    const regex = new RegExp(${search}, 'g');
    const updated = content.replace(regex, \`${replace}\`);
    if (content !== updated) {
      fs.writeFileSync('${file}', updated);
      process.stdout.write('changed');
    } else {
      process.stdout.write('unchanged');
    }
  "
}

# ----------------------------------------------------------------------------- 
# Kiểm tra môi trường
# ----------------------------------------------------------------------------- 
check_environment() {
  log_section "Kiểm tra môi trường"
  require_cmd node
  require_cmd npx

  NODE_VERSION=$(node -e "process.stdout.write(process.version)")
  log_info "Node.js: ${NODE_VERSION}"

  detect_package_manager

  if [[ ! -f "${PROJECT_ROOT}/package.json" ]]; then
    log_error "Không tìm thấy package.json tại: ${PROJECT_ROOT}"
    exit 1
  fi
  log_ok "Môi trường OK"
}

# ----------------------------------------------------------------------------- 
# FIX 1: Router – createBrowserRouter → createHashRouter
# Capacitor chạy file:// nên không hỗ trợ history API
# ----------------------------------------------------------------------------- 
fix_router() {
  log_section "Fix 1: Router (BrowserRouter → HashRouter)"

  if [[ ! -f "$APP_JSX" ]]; then
    log_warn "Không tìm thấy src/App.jsx, bỏ qua bước fix router"
    return
  fi

  # Kiểm tra xem đã dùng HashRouter chưa
  if grep -q "createHashRouter" "$APP_JSX"; then
    log_ok "createHashRouter đã được sử dụng, không cần thay đổi"
    return
  fi

  if ! grep -q "createBrowserRouter" "$APP_JSX"; then
    log_warn "Không tìm thấy createBrowserRouter trong App.jsx"
    return
  fi

  backup_file "$APP_JSX"

  # Thay thế import
  result=$(node_replace \
    "$APP_JSX" \
    '"createBrowserRouter"' \
    'createHashRouter')

  # Thay thế import statement
  node -e "
    const fs = require('fs');
    let content = fs.readFileSync('${APP_JSX}', 'utf8');

    // Thay trong import list
    content = content.replace(/\bcreateBrowserRouter\b/g, 'createHashRouter');

    // Xóa ScrollRestoration import vì HashRouter vẫn dùng được nhưng
    // ScrollRestoration hoạt động tốt với HashRouter - giữ nguyên

    fs.writeFileSync('${APP_JSX}', content);
    console.log('Router updated: createBrowserRouter → createHashRouter');
  "

  log_ok "Router đã được cập nhật"

  # Thêm comment giải thích
  node -e "
    const fs = require('fs');
    let content = fs.readFileSync('${APP_JSX}', 'utf8');
    if (!content.includes('Capacitor: HashRouter')) {
      content = content.replace(
        'const router = createHashRouter',
        '// Capacitor: HashRouter required for file:// protocol (native mobile)\nconst router = createHashRouter'
      );
      fs.writeFileSync('${APP_JSX}', content);
    }
  "
}

# ----------------------------------------------------------------------------- 
# FIX 2: Vite config – thêm base: './'
# Đảm bảo assets được load đúng khi chạy từ file://
# ----------------------------------------------------------------------------- 
fix_vite_config() {
  log_section "Fix 2: Vite config (base: './')"

  if [[ ! -f "$VITE_CONFIG" ]]; then
    log_warn "Không tìm thấy vite.config.js, bỏ qua"
    return
  fi

  if grep -q "base:" "$VITE_CONFIG"; then
    log_ok "vite.config.js đã có 'base:', kiểm tra giá trị..."
    if grep -q "base: '\./'" "$VITE_CONFIG" || grep -q 'base: "./"' "$VITE_CONFIG"; then
      log_ok "base đã là './', không cần thay đổi"
      return
    else
      log_warn "base có giá trị khác, sẽ cập nhật thành './'"
      backup_file "$VITE_CONFIG"
      node -e "
        const fs = require('fs');
        let content = fs.readFileSync('${VITE_CONFIG}', 'utf8');
        content = content.replace(/base:\s*['\"]\//g, \"base: './\");
        fs.writeFileSync('${VITE_CONFIG}', content);
        console.log('base updated');
      "
      return
    fi
  fi

  backup_file "$VITE_CONFIG"

  # Thêm base vào trong return {} của defineConfig
  # Chèn sau dấu { đầu tiên của return {
  node -e "
    const fs = require('fs');
    let content = fs.readFileSync('${VITE_CONFIG}', 'utf8');

    // Tìm 'return {' và thêm base ngay sau
    const returnMatch = content.match(/return\s*\{/);
    if (returnMatch) {
      const idx = content.indexOf(returnMatch[0]) + returnMatch[0].length;
      // Kiểm tra xem đã có base chưa
      const before = content.slice(0, idx);
      const after = content.slice(idx);
      // Thêm base sau 'return {'
      const newContent = before + '\n    // Capacitor: base path cho native build\n    base: \'./\',' + after;
      fs.writeFileSync('${VITE_CONFIG}', newContent);
      console.log('base added to vite.config.js');
    } else {
      console.error('Không tìm thấy return { trong vite.config.js');
      process.exit(1);
    }
  "

  log_ok "vite.config.js đã được cập nhật với base: './'"
}

# ----------------------------------------------------------------------------- 
# FIX 3: index.html – xóa script sandbox VibEx
# Các script sandbox không hoạt động trong môi trường native
# ----------------------------------------------------------------------------- 
fix_index_html() {
  log_section "Fix 3: index.html (xóa script sandbox)"

  if [[ ! -f "$INDEX_HTML" ]]; then
    log_warn "Không tìm thấy index.html, bỏ qua"
    return
  fi

  local changed=false

  # Kiểm tra xem có script cần xóa không
  if grep -q "dev-cdn.vibe-x.app" "$INDEX_HTML"; then
    backup_file "$INDEX_HTML"
    node -e "
      const fs = require('fs');
      let content = fs.readFileSync('${INDEX_HTML}', 'utf8');

      // Xóa các script tag từ dev-cdn.vibe-x.app (multiline safe)
      const before = content;
      content = content.replace(
        /<script[^>]*dev-cdn\.vibe-x\.app[^>]*>[\s\S]*?<\/script>/gm,
        ''
      );
      // Xóa các script self-closing từ dev-cdn.vibe-x.app
      content = content.replace(
        /<script[^>]*dev-cdn\.vibe-x\.app[^>]*\/?>/gm,
        ''
      );
      // Dọn dòng trắng thừa
      content = content.replace(/\n\s*\n\s*\n/g, '\n\n');

      if (before !== content) {
        fs.writeFileSync('${INDEX_HTML}', content);
        console.log('Removed VibEx sandbox scripts from index.html');
      } else {
        console.log('No VibEx scripts found or already removed');
      }
    "
    changed=true
    log_ok "Đã xóa script sandbox VibEx"
  else
    log_ok "Không có script sandbox VibEx, bỏ qua"
  fi

  # Thêm meta tag cho Capacitor CSP (nếu chưa có)
  if ! grep -q "capacitor://" "$INDEX_HTML"; then
    [[ "$changed" == "false" ]] && backup_file "$INDEX_HTML"
    node -e "
      const fs = require('fs');
      let content = fs.readFileSync('${INDEX_HTML}', 'utf8');

      // Thêm meta CSP sau thẻ <head>
      const cspMeta = '    <meta http-equiv=\"Content-Security-Policy\" content=\"default-src * data: blob: capacitor: filesystem: 'unsafe-inline' 'unsafe-eval'; style-src * 'unsafe-inline'; img-src * data: blob: capacitor:; media-src * data: blob: capacitor:\">';
      content = content.replace(
        /(<head[^>]*>)/i,
        '\$1\n' + cspMeta
      );
      fs.writeFileSync('${INDEX_HTML}', content);
      console.log('Added Capacitor CSP meta tag');
    "
    log_ok "Đã thêm Capacitor CSP meta tag"
  fi
}

# ----------------------------------------------------------------------------- 
# FIX 4: Tạo capacitor.config.json
# ----------------------------------------------------------------------------- 
create_capacitor_config() {
  log_section "Tạo capacitor.config.json"

  if [[ -f "$CAP_CONFIG" ]]; then
    log_ok "capacitor.config.json đã tồn tại"
    # Kiểm tra webDir
    local current_webdir
    current_webdir=$(node -e "
      const c = require('${CAP_CONFIG}');
      process.stdout.write(c.webDir || '');
    " 2>/dev/null || echo "")
    if [[ "$current_webdir" != "$WEB_DIR" ]]; then
      log_warn "webDir hiện tại: '${current_webdir}', cần: '${WEB_DIR}'"
      backup_file "$CAP_CONFIG"
      node -e "
        const fs = require('fs');
        const config = JSON.parse(fs.readFileSync('${CAP_CONFIG}', 'utf8'));
        config.webDir = '${WEB_DIR}';
        fs.writeFileSync('${CAP_CONFIG}', JSON.stringify(config, null, 2));
        console.log('webDir updated');
      "
    fi
    return
  fi

  cat > "$CAP_CONFIG" << EOF
{
  "appId": "${APP_ID}",
  "appName": "${APP_NAME}",
  "webDir": "${WEB_DIR}",
  "server": {
    "androidScheme": "https",
    "allowNavigation": [
      "*.youtube.com",
      "*.googleapis.com",
      "*.google.com"
    ]
  },
  "plugins": {
    "SplashScreen": {
      "launchShowDuration": 2000,
      "launchAutoHide": true,
      "backgroundColor": "#09090b",
      "androidSplashResourceName": "splash",
      "androidScaleType": "CENTER_CROP",
      "showSpinner": false
    },
    "StatusBar": {
      "style": "Dark",
      "backgroundColor": "#09090b"
    }
  },
  "ios": {
    "scheme": "App"
  },
  "android": {
    "allowMixedContent": true,
    "captureInput": true
  }
}
EOF

  log_ok "Đã tạo capacitor.config.json"
}

# ----------------------------------------------------------------------------- 
# STEP: Cài Capacitor packages
# ----------------------------------------------------------------------------- 
install_capacitor() {
  log_section "Cài đặt Capacitor packages"

  # Kiểm tra xem @capacitor/core đã có chưa
  if node -e "require('@capacitor/core')" &>/dev/null 2>&1; then
    log_ok "@capacitor/core đã được cài, kiểm tra version..."
  else
    log_info "Đang cài @capacitor/core và @capacitor/cli..."
    pkg_install false @capacitor/core
    pkg_install true @capacitor/cli
    log_ok "@capacitor/core, @capacitor/cli đã được cài"
  fi

  # Cài platform packages nếu được chỉ định
  if [[ -n "$PLATFORMS" ]]; then
    for platform in $PLATFORMS; do
      case "$platform" in
        ios)
          if node -e "require('@capacitor/ios')" &>/dev/null 2>&1; then
            log_ok "@capacitor/ios đã được cài"
          else
            log_info "Cài @capacitor/ios..."
            pkg_install false @capacitor/ios
          fi
          ;;
        android)
          if node -e "require('@capacitor/android')" &>/dev/null 2>&1; then
            log_ok "@capacitor/android đã được cài"
          else
            log_info "Cài @capacitor/android..."
            pkg_install false @capacitor/android
          fi
          ;;
        *)
          log_warn "Platform không hỗ trợ: $platform"
          ;;
      esac
    done
  fi
}

# ----------------------------------------------------------------------------- 
# STEP: Build web app
# ----------------------------------------------------------------------------- 
build_web() {
  log_section "Build web app"

  cd "$PROJECT_ROOT"

  # Auto detect build command
  if [[ -z "$BUILD_CMD" ]]; then
    if grep -q '"build"' package.json; then
      BUILD_CMD="${PACKAGE_MANAGER} run build"
      if [[ "$PACKAGE_MANAGER" == "pnpm" ]]; then
        BUILD_CMD="pnpm run build"
      elif [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
        BUILD_CMD="yarn build"
      fi
    fi
  fi

  log_info "Chạy: ${BUILD_CMD}"
  eval "$BUILD_CMD"

  if [[ ! -d "$WEB_DIR" ]]; then
    log_error "Thư mục build '${WEB_DIR}' không tồn tại sau khi build!"
    exit 1
  fi

  log_ok "Build thành công → ${WEB_DIR}/"
}

# ----------------------------------------------------------------------------- 
# STEP: Khởi tạo Capacitor
# ----------------------------------------------------------------------------- 
init_capacitor() {
  log_section "Khởi tạo Capacitor"

  cd "$PROJECT_ROOT"

  # Kiểm tra xem đã init chưa (có node_modules/@capacitor/core)
  if [[ -f "${PROJECT_ROOT}/node_modules/.bin/cap" ]]; then
    log_ok "Capacitor CLI đã sẵn sàng"
  else
    log_warn "Capacitor CLI chưa được cài trong node_modules"
  fi

  # Nếu chưa có platform directories → chạy init
  local needs_init=false
  if [[ ! -d "${PROJECT_ROOT}/ios" ]] && [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    needs_init=true
  fi

  if [[ "$needs_init" == "true" ]]; then
    log_info "Chạy cap init..."
    run_npx cap init \
      "${APP_NAME}" \
      "${APP_ID}" \
      --web-dir "${WEB_DIR}" || {
        log_warn "cap init có lỗi, thử tiếp..."
      }
  else
    log_ok "Capacitor đã được khởi tạo (platform dirs tồn tại)"
  fi
}

# ----------------------------------------------------------------------------- 
# STEP: Add platforms
# ----------------------------------------------------------------------------- 
add_platforms() {
  log_section "Add platforms"

  if [[ -z "$PLATFORMS" ]]; then
    log_info "Không có platform nào được chỉ định (CAP_PLATFORMS), bỏ qua"
    log_info "Để thêm platform: export CAP_PLATFORMS='android' hoặc 'ios android'"
    return
  fi

  cd "$PROJECT_ROOT"

  for platform in $PLATFORMS; do
    if [[ -d "${PROJECT_ROOT}/${platform}" ]]; then
      log_ok "Platform '${platform}' đã tồn tại"
    else
      log_info "Thêm platform: ${platform}"
      run_npx cap add "$platform"
      log_ok "Đã thêm platform: ${platform}"
    fi
  done
}

# ----------------------------------------------------------------------------- 
# STEP: Capacitor sync
# ----------------------------------------------------------------------------- 
sync_capacitor() {
  log_section "Capacitor Sync"

  cd "$PROJECT_ROOT"

  log_info "Chạy cap sync..."
  run_npx cap sync

  log_ok "cap sync hoàn tất"
}

# ----------------------------------------------------------------------------- 
# FIX 5: Fix thêm cho iOS – Info.plist NSAppTransportSecurity
# ----------------------------------------------------------------------------- 
fix_ios_transport_security() {
  local plist="${PROJECT_ROOT}/ios/App/App/Info.plist"

  if [[ ! -f "$plist" ]]; then
    log_info "Info.plist chưa tồn tại (iOS chưa được add), bỏ qua"
    return
  fi

  log_section "Fix iOS NSAppTransportSecurity"

  if grep -q "NSAllowsArbitraryLoads" "$plist"; then
    log_ok "NSAppTransportSecurity đã được cấu hình"
    return
  fi

  backup_file "$plist"

  # Thêm NSAppTransportSecurity vào plist
  python3 - << 'PYEOF'
import plistlib, sys, os

plist_path = os.environ.get('PLIST_PATH', '')
with open(plist_path, 'rb') as f:
    plist = plistlib.load(f)

if 'NSAppTransportSecurity' not in plist:
    plist['NSAppTransportSecurity'] = {
        'NSAllowsArbitraryLoads': True,
        'NSAllowsArbitraryLoadsInWebContent': True,
    }
    with open(plist_path, 'wb') as f:
        plistlib.dump(plist, f)
    print(f"Updated {plist_path}")
else:
    print("NSAppTransportSecurity already exists")
PYEOF

  log_ok "iOS NSAppTransportSecurity đã được cấu hình"
}

# ----------------------------------------------------------------------------- 
# FIX 6: Fix Android – network_security_config
# ----------------------------------------------------------------------------- 
fix_android_network_security() {
  local android_res="${PROJECT_ROOT}/android/app/src/main/res/xml"
  local network_config="${android_res}/network_security_config.xml"
  local manifest="${PROJECT_ROOT}/android/app/src/main/AndroidManifest.xml"

  if [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_info "Platform android chưa được add, bỏ qua"
    return
  fi

  log_section "Fix Android Network Security"

  mkdir -p "$android_res"

  if [[ ! -f "$network_config" ]]; then
    cat > "$network_config" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
EOF
    log_ok "Đã tạo network_security_config.xml"
  else
    log_ok "network_security_config.xml đã tồn tại"
  fi

  # Thêm networkSecurityConfig vào AndroidManifest nếu chưa có
  if [[ -f "$manifest" ]] && ! grep -q "networkSecurityConfig" "$manifest"; then
    backup_file "$manifest"
    node -e "
      const fs = require('fs');
      let content = fs.readFileSync('${manifest}', 'utf8');
      content = content.replace(
        /(<application)/,
        '\$1\n        android:networkSecurityConfig=\"@xml/network_security_config\"'
      );
      fs.writeFileSync('${manifest}', content);
      console.log('Added networkSecurityConfig to AndroidManifest.xml');
    "
    log_ok "AndroidManifest.xml đã được cập nhật"
  fi
}

# ----------------------------------------------------------------------------- 
# Tóm tắt
# ----------------------------------------------------------------------------- 
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║         ✅ CAPACITOR SETUP HOÀN TẤT             ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${BOLD}Các thay đổi đã thực hiện:${RESET}"
  echo -e "  ${GREEN}✓${RESET} Router: createBrowserRouter → createHashRouter"
  echo -e "  ${GREEN}✓${RESET} Vite: thêm base: './'"
  echo -e "  ${GREEN}✓${RESET} index.html: xóa script sandbox VibEx"
  echo -e "  ${GREEN}✓${RESET} capacitor.config.json đã được tạo/cập nhật"
  echo -e "  ${GREEN}✓${RESET} Web app đã được build"
  echo -e "  ${GREEN}✓${RESET} Capacitor sync hoàn tất"
  echo ""
  echo -e "${BOLD}Bước tiếp theo:${RESET}"
  if echo "$PLATFORMS" | grep -q "ios"; then
    echo -e "  ${CYAN}iOS:${RESET}     npx cap open ios"
    echo -e "           → Chọn device/simulator trong Xcode → Build & Run"
  fi
  if echo "$PLATFORMS" | grep -q "android"; then
    echo -e "  ${CYAN}Android:${RESET} npx cap open android"
    echo -e "           → Chọn device trong Android Studio → Build & Run"
  fi
  echo ""
  echo -e "${YELLOW}⚠  Backend CORS:${RESET} Thêm 'capacitor://localhost' vào"
  echo -e "   danh sách allowed origins trên server của bạn."
  echo ""
  echo -e "${YELLOW}⚠  File backup:${RESET} Các file gốc đã được backup với"
  echo -e "   suffix '${BACKUP_SUFFIX}'"
  echo ""
}

# ----------------------------------------------------------------------------- 
# Main
# ----------------------------------------------------------------------------- 
main() {
  echo ""
  echo -e "${BOLD}${CYAN}🚀 Capacitor Setup Script cho K Screens${RESET}"
  echo -e "${CYAN}   $(date)${RESET}"
  echo ""

  cd "$PROJECT_ROOT"

  check_environment

  # --- Fixes code trước khi build ---
  fix_router
  fix_vite_config
  fix_index_html

  # --- Cài Capacitor ---
  install_capacitor

  # --- Tạo config ---
  create_capacitor_config

  # --- Build ---
  build_web

  # --- Init & add platforms ---
  init_capacitor
  add_platforms

  # --- Sync ---
  sync_capacitor

  # --- Fix platform-specific ---
  fix_ios_transport_security
  fix_android_network_security

  print_summary
}

main "$@"
