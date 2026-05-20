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
APP_ID="${CAP_APP_ID:-com.kscreens.app}"
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

# Fastlane config
SKIP_FASTLANE="${SKIP_FASTLANE:-false}"     # đặt true để bỏ qua bước Fastlane
FL_APP_LANGUAGE="${FL_APP_LANGUAGE:-ko}"    # ngôn ngữ chính của app trên ASC
FL_APP_SKU="${FL_APP_SKU:-}"                # SKU trên ASC (để trống → tự tạo từ APP_ID)

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
  # Truyền PLIST_PATH qua inline env để python3 subprocess nhận được
  PLIST_PATH="$plist" python3 - << 'PYEOF'
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

# =============================================================================
# FASTLANE SETUP
# Được gọi SAU KHI add_platforms() và sync_capacitor() đã hoàn tất
# Chỉ chạy khi: SKIP_FASTLANE != "true"
# =============================================================================

# ----------------------------------------------------------------------------- 
# Kiểm tra Ruby và Bundler
# ----------------------------------------------------------------------------- 
check_ruby() {
  if ! command -v ruby &>/dev/null; then
    log_error "Ruby chưa được cài. Fastlane yêu cầu Ruby >= 2.7"
    log_info  "  macOS: brew install ruby"
    log_info  "  Linux: sudo apt install ruby-full"
    return 1
  fi
  local ruby_ver
  ruby_ver=$(ruby -e "puts RUBY_VERSION")
  log_info "Ruby: ${ruby_ver}"

  if ! command -v bundle &>/dev/null; then
    log_info "Cài bundler..."
    gem install bundler --no-document
  fi
  log_ok "Ruby + Bundler sẵn sàng"
  return 0
}

# ----------------------------------------------------------------------------- 
# Tạo Gemfile
# ----------------------------------------------------------------------------- 
create_gemfile() {
  local gemfile="${PROJECT_ROOT}/Gemfile"

  if [[ -f "$gemfile" ]]; then
    # Kiểm tra xem fastlane đã có trong Gemfile chưa
    if grep -q 'fastlane' "$gemfile"; then
      log_ok "Gemfile đã chứa fastlane"
      return
    fi
    backup_file "$gemfile"
  fi

  log_info "Tạo Gemfile..."
  cat > "$gemfile" << 'GEMEOF'
source "https://rubygems.org"

# Fastlane - iOS/Android automation
gem "fastlane", ">= 2.220.0"

# JWT cho App Store Connect API (ES256)
gem "jwt", ">= 2.7.0"

# HTTP client cho ASC REST API
gem "faraday", ">= 2.0"
gem "faraday-retry", ">= 2.0"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
GEMEOF
  log_ok "Gemfile đã được tạo"
}

# ----------------------------------------------------------------------------- 
# Tạo fastlane/Appfile
# ----------------------------------------------------------------------------- 
create_appfile() {
  local appfile="${PROJECT_ROOT}/fastlane/Appfile"
  mkdir -p "${PROJECT_ROOT}/fastlane"

  if [[ -f "$appfile" ]]; then
    log_ok "fastlane/Appfile đã tồn tại"
    return
  fi

  log_info "Tạo fastlane/Appfile..."
  cat > "$appfile" << APPEOF
# Fastlane Appfile – K Screens
# Đọc từ biến môi trường CI/CD (không hardcode credentials)

app_identifier(ENV["APP_BUNDLE_ID"] || "${APP_ID}")
apple_id(ENV["APPLE_ID"] || "")
team_id(ENV["APPLE_TEAM_ID"] || "")
itc_team_id(ENV["ITC_TEAM_ID"] || ENV["APPLE_TEAM_ID"] || "")
APPEOF
  log_ok "fastlane/Appfile đã được tạo"
}

# ----------------------------------------------------------------------------- 
# Tạo fastlane/actions/create_bundle_id.rb
# Custom action gọi trực tiếp ASC REST API để tạo Bundle ID
# ----------------------------------------------------------------------------- 
create_asc_action() {
  local actions_dir="${PROJECT_ROOT}/fastlane/actions"
  mkdir -p "$actions_dir"

  local action_file="${actions_dir}/create_bundle_id.rb"
  if [[ -f "$action_file" ]]; then
    log_ok "fastlane/actions/create_bundle_id.rb đã tồn tại"
    return
  fi

  log_info "Tạo custom action create_bundle_id.rb..."
  cat > "$action_file" << 'RBEOF'
# fastlane/actions/create_bundle_id.rb
#
# Custom Fastlane action: Tạo Bundle ID trên Apple Developer Portal
# thông qua App Store Connect REST API v1
#
# Sử dụng JWT (ES256) để xác thực – không cần username/password
#
require "net/http"
require "json"
require "openssl"
require "base64"
require "time"

module Fastlane
  module Actions
    class CreateBundleIdAction < Action
      # -----------------------------------------------------------------------
      # Tạo JWT token để xác thực với ASC API
      # Spec: https://developer.apple.com/documentation/appstoreconnectapi/generating_tokens_for_api_requests
      # -----------------------------------------------------------------------
      def self.generate_jwt(key_id:, issuer_id:, key_content:)
        header = {
          alg: "ES256",
          kid: key_id,
          typ: "JWT",
        }

        now = Time.now.to_i
        payload = {
          iss: issuer_id,
          iat: now,
          exp: now + 1200,   # tối đa 20 phút
          aud: "appstoreconnect-v1",
        }

        # Load private key (.p8 format)
        private_key = OpenSSL::PKey::EC.new(key_content)

        # Encode header + payload
        b64 = ->(data) { Base64.urlsafe_encode64(data, padding: false) }
        signing_input = "#{b64.call(header.to_json)}.#{b64.call(payload.to_json)}"

        # Sign bằng ES256
        digest    = OpenSSL::Digest::SHA256.new
        asn1_sig  = private_key.sign(digest, signing_input)
        # Convert DER/ASN.1 → raw R||S (64 bytes)
        asn1      = OpenSSL::ASN1.decode(asn1_sig)
        r = asn1.value[0].value.to_s(2).rjust(32, "\x00")[-32..]
        s = asn1.value[1].value.to_s(2).rjust(32, "\x00")[-32..]
        raw_sig   = r + s

        "#{signing_input}.#{b64.call(raw_sig)}"
      end

      # -----------------------------------------------------------------------
      # Gọi ASC API POST /v1/bundleIds
      # -----------------------------------------------------------------------
      def self.run(params)
        key_id      = params[:api_key_id]
        issuer_id   = params[:api_issuer_id]
        key_content = params[:api_key_content]
        bundle_id   = params[:bundle_id]
        name        = params[:name]
        platform    = params[:platform] || "IOS"

        UI.message("[ASC API] Tạo Bundle ID: #{bundle_id}")

        token = generate_jwt(
          key_id:      key_id,
          issuer_id:   issuer_id,
          key_content: key_content,
        )

        body = {
          data: {
            type: "bundleIds",
            attributes: {
              identifier: bundle_id,
              name:       name,
              platform:   platform,
            },
          },
        }.to_json

        uri  = URI("https://api.appstoreconnect.apple.com/v1/bundleIds")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.read_timeout = 30

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"]  = "application/json"
        request.body = body

        response = http.request(request)
        data     = JSON.parse(response.body)

        case response.code.to_i
        when 201
          attrs = data.dig("data", "attributes") || {}
          UI.success("[ASC API] Bundle ID tạo thành công!")
          {
            success:    true,
            id:         data.dig("data", "id"),
            identifier: attrs["identifier"],
            name:       attrs["name"],
            platform:   attrs["platform"],
          }
        when 409
          # ENTITY_ALREADY_EXISTS – không phải lỗi
          error_detail = data.dig("errors", 0, "detail") || "already exists"
          UI.important("[ASC API] Bundle ID đã tồn tại: #{error_detail}")
          # Fetch existing bundle id info
          fetch_existing_bundle_id(token, bundle_id)
        else
          error_msg = data.dig("errors", 0, "detail") ||
                      data.dig("errors", 0, "title") ||
                      response.body
          UI.error("[ASC API] Lỗi #{response.code}: #{error_msg}")
          { success: false, error: error_msg }
        end
      rescue => e
        UI.error("[ASC API] Exception: #{e.message}")
        { success: false, error: e.message }
      end

      # -----------------------------------------------------------------------
      # Lấy thông tin Bundle ID đã có
      # GET /v1/bundleIds?filter[identifier]=<id>
      # -----------------------------------------------------------------------
      def self.fetch_existing_bundle_id(token, identifier)
        uri = URI("https://api.appstoreconnect.apple.com/v1/bundleIds")
        uri.query = URI.encode_www_form("filter[identifier]" => identifier)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{token}"

        response = http.request(request)
        data     = JSON.parse(response.body)
        first    = data.dig("data", 0)

        return { success: false, error: "Bundle ID not found" } unless first

        attrs = first["attributes"] || {}
        {
          success:    true,
          id:         first["id"],
          identifier: attrs["identifier"],
          name:       attrs["name"],
          platform:   attrs["platform"],
        }
      end

      def self.description
        "Tạo Bundle ID trên Apple Developer Portal qua App Store Connect REST API"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key:         :api_key_id,
            description: "Key ID từ App Store Connect API Keys",
            type:        String,
          ),
          FastlaneCore::ConfigItem.new(
            key:         :api_issuer_id,
            description: "Issuer ID từ App Store Connect",
            type:        String,
          ),
          FastlaneCore::ConfigItem.new(
            key:         :api_key_content,
            description: "Nội dung file .p8 (private key)",
            type:        String,
            sensitive:   true,
          ),
          FastlaneCore::ConfigItem.new(
            key:         :bundle_id,
            description: "Bundle Identifier (vd: com.kscreens.app)",
            type:        String,
          ),
          FastlaneCore::ConfigItem.new(
            key:         :name,
            description: "Tên hiển thị của Bundle ID",
            type:        String,
          ),
          FastlaneCore::ConfigItem.new(
            key:         :platform,
            description: "IOS hoặc MAC_OS",
            default_value: "IOS",
            type:        String,
          ),
        ]
      end

      def self.return_value
        "Hash chứa: success, id, identifier, name, platform (hoặc error khi thất bại)"
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
RBEOF
  log_ok "fastlane/actions/create_bundle_id.rb đã được tạo"
}

# ----------------------------------------------------------------------------- 
# Tạo fastlane/Fastfile
# ----------------------------------------------------------------------------- 
create_fastfile() {
  local fastfile="${PROJECT_ROOT}/fastlane/Fastfile"

  if [[ -f "$fastfile" ]]; then
    log_ok "fastlane/Fastfile đã tồn tại"
    return
  fi

  log_info "Tạo fastlane/Fastfile..."
  cat > "$fastfile" << FFEOF
# =============================================================================
# Fastfile – ${APP_NAME}
# Auto-generated by add-capacitor.sh
#
# Lanes:
#   bundle exec fastlane create_bundle_id   → Tạo Bundle ID qua ASC API
#   bundle exec fastlane create_app         → Tạo app trên App Store Connect
#   bundle exec fastlane setup_signing      → Tạo cert + provisioning (match)
#   bundle exec fastlane build_ios          → Build IPA
#   bundle exec fastlane release_testflight → Upload TestFlight
#   bundle exec fastlane full_setup         → Chạy toàn bộ flow
#   bundle exec fastlane ci_pipeline        → Lane tự động cho CI/CD
#
# Biến môi trường cần thiết:
#   ASC_KEY_ID, ASC_ISSUER_ID
#   ASC_PRIVATE_KEY_CONTENT  (base64 của file .p8)
#   APP_BUNDLE_ID, APP_NAME, APPLE_ID, APPLE_TEAM_ID
# =============================================================================

require "json"
require "base64"
require "time"

# Đọc API Key cho App Store Connect
def asc_api_key
  key_content = ENV["ASC_PRIVATE_KEY_CONTENT"]

  # Nếu là base64-encoded (CI/CD secrets thường lưu dạng này)
  if key_content && !key_content.include?("-----BEGIN")
    key_content = Base64.decode64(key_content)
  end

  if key_content.nil? || key_content.empty?
    key_path = ENV["ASC_PRIVATE_KEY_PATH"] || "fastlane/asc_private_key.p8"
    UI.user_error!("ASC private key không tìm thấy: #{key_path}") unless File.exist?(key_path)
    key_content = File.read(key_path)
  end

  {
    key_id:      ENV["ASC_KEY_ID"]     || UI.user_error!("Thiếu ASC_KEY_ID"),
    issuer_id:   ENV["ASC_ISSUER_ID"]  || UI.user_error!("Thiếu ASC_ISSUER_ID"),
    key_content: key_content,
    is_key_content_base64: false,
    duration:    1200,
    in_house:    false,
  }
end

# -----------------------------------------------------------------------
# LANE: create_bundle_id
# Tạo Bundle ID qua App Store Connect REST API
# -----------------------------------------------------------------------
lane :create_bundle_id do |options|
  UI.header("🆔 Tạo Bundle ID qua App Store Connect API")

  bundle_id = options[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  name      = options[:name]      || ENV["APP_NAME"]      || "${APP_NAME}"
  platform  = options[:platform]  || "IOS"
  api_key   = asc_api_key

  result = Actions::CreateBundleIdAction.run(
    api_key_id:      api_key[:key_id],
    api_issuer_id:   api_key[:issuer_id],
    api_key_content: api_key[:key_content],
    bundle_id:       bundle_id,
    name:            name,
    platform:        platform,
  )

  if result[:success]
    UI.success("✅ Bundle ID: #{result[:identifier]} (id=#{result[:id]})")
    File.write("fastlane/bundle_id_result.json", JSON.pretty_generate(result))
  else
    unless result[:error].to_s.include?("ENTITY_ALREADY_EXISTS") ||
           result[:error].to_s.include?("already exists")
      UI.user_error!(result[:error])
    end
    UI.important("Bundle ID đã tồn tại, tiếp tục...")
  end
end

# -----------------------------------------------------------------------
# LANE: create_app
# Tạo app trên App Store Connect dùng produce action
# -----------------------------------------------------------------------
lane :create_app do |options|
  UI.header("📱 Tạo App trên App Store Connect")

  bundle_id = options[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  app_name  = options[:app_name]  || ENV["APP_NAME"]      || "${APP_NAME}"
  sku       = options[:sku]       || ENV["APP_SKU"] || bundle_id.gsub(".", "-")
  language  = options[:language]  || ENV["APP_LANGUAGE"]  || "${FL_APP_LANGUAGE}"

  # Đảm bảo Bundle ID tồn tại trước
  create_bundle_id(bundle_id: bundle_id, name: app_name)

  produce(
    app_identifier: bundle_id,
    app_name:       app_name,
    language:       language,
    app_version:    ENV["APP_VERSION"] || "1.0.0",
    sku:            sku,
    platform:       "ios",
    skip_itc:       false,
    skip_devcenter: false,
    enable_services: {
      push_notification: "on",
      associated_domains: "on",
    },
  )

  UI.success("✅ App đã được tạo trên App Store Connect!")
end

# -----------------------------------------------------------------------
# LANE: setup_signing
# Quản lý certificates + provisioning profiles bằng match
# -----------------------------------------------------------------------
lane :setup_signing do |options|
  UI.header("🔑 Setup Code Signing (Match)")

  bundle_id = options[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  type      = options[:type]      || ENV["MATCH_TYPE"]    || "appstore"
  match_url = ENV["MATCH_GIT_URL"] || UI.user_error!("Thiếu MATCH_GIT_URL")

  match(
    type:                  type,
    app_identifier:        bundle_id,
    git_url:               match_url,
    git_branch:            ENV["MATCH_GIT_BRANCH"] || "main",
    password:              ENV["MATCH_PASSWORD"],
    readonly:              ENV["CI"] ? true : false,
    clone_branch_directly: true,
    force_for_new_devices: !ENV["CI"],
    api_key:               asc_api_key,
  )

  UI.success("✅ Code signing setup hoàn tất (type=#{type})")
end

# -----------------------------------------------------------------------
# LANE: build_ios – Build IPA
# -----------------------------------------------------------------------
lane :build_ios do |options|
  UI.header("🏗️  Build iOS IPA")

  bundle_id = options[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  scheme    = options[:scheme]    || ENV["IOS_SCHEME"]    || "App"
  config    = options[:config]    || ENV["BUILD_CONFIG"]  || "Release"

  setup_signing(bundle_id: bundle_id, type: "appstore") unless options[:skip_signing]

  gym(
    scheme:            scheme,
    configuration:     config,
    export_method:     "app-store",
    output_directory:  "build",
    output_name:       "App.ipa",
    clean:             true,
    include_symbols:   true,
    include_bitcode:   false,
    xcargs:            "DEVELOPMENT_TEAM=#{ENV["APPLE_TEAM_ID"]}",
    export_options: {
      provisioningProfiles: {
        bundle_id => "match AppStore #{bundle_id}",
      },
    },
  )

  UI.success("✅ Build xong! IPA: build/App.ipa")
end

# -----------------------------------------------------------------------
# LANE: release_testflight – Upload lên TestFlight
# -----------------------------------------------------------------------
lane :release_testflight do |options|
  UI.header("🚀 Upload lên TestFlight")

  pilot(
    api_key:                           asc_api_key,
    ipa:                               options[:ipa_path] || "build/App.ipa",
    skip_waiting_for_build_processing: true,
    distribute_external:               false,
    notify_external_testers:           false,
    changelog:                         options[:changelog] || ENV["RELEASE_NOTES"] || "Build mới",
    beta_app_description:              "${APP_NAME}",
    demo_account_required:             false,
  )

  UI.success("✅ Upload TestFlight thành công!")
end

# -----------------------------------------------------------------------
# LANE: full_setup – Toàn bộ flow từ đầu (dùng lần đầu setup project)
# -----------------------------------------------------------------------
lane :full_setup do |options|
  UI.header("🎬 Full Setup – ${APP_NAME}")

  bundle_id = options[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  app_name  = options[:app_name]  || ENV["APP_NAME"]      || "${APP_NAME}"

  create_bundle_id(bundle_id: bundle_id, name: app_name)
  create_app(bundle_id: bundle_id, app_name: app_name)

  if ENV["MATCH_GIT_URL"] && !ENV["MATCH_GIT_URL"].empty?
    setup_signing(bundle_id: bundle_id, type: "development")
    setup_signing(bundle_id: bundle_id, type: "appstore")
  else
    UI.important("Bỏ qua setup_signing (MATCH_GIT_URL chưa có)")
  end

  UI.success("🎉 Full setup hoàn tất!")
end

# -----------------------------------------------------------------------
# LANE: ci_pipeline – Lane tổng dành cho CI/CD tự động
# -----------------------------------------------------------------------
lane :ci_pipeline do
  UI.header("⚙️  CI/CD Pipeline – ${APP_NAME}")

  create_bundle_id  unless ENV["SKIP_ASC_SETUP"] == "true"
  create_app        unless ENV["SKIP_ASC_SETUP"] == "true"
  build_ios         unless ENV["SKIP_BUILD"]    == "true"
  release_testflight(
    changelog: ENV["RELEASE_NOTES"] || "CI build - \#{Time.now.strftime('%Y-%m-%d %H:%M')}",
  )               unless ENV["SKIP_UPLOAD"]   == "true"
end

error do |lane, exception|
  UI.error("❌ Lane '#{lane}' lỗi: #{exception.message}")
  if ENV["SLACK_WEBHOOK_URL"] && !ENV["SLACK_WEBHOOK_URL"].empty?
    slack(
      message:          "❌ ${APP_NAME} build lỗi: #{exception.message}",
      slack_url:        ENV["SLACK_WEBHOOK_URL"],
      success:          false,
      default_payloads: [:lane, :git_branch, :git_author],
    )
  end
end
FFEOF
  log_ok "fastlane/Fastfile đã được tạo"
}

# ----------------------------------------------------------------------------- 
# Tạo .env.example để hướng dẫn cấu hình CI/CD
# ----------------------------------------------------------------------------- 
create_env_example() {
  local env_file="${PROJECT_ROOT}/.env.fastlane.example"

  if [[ -f "$env_file" ]]; then
    log_ok ".env.fastlane.example đã tồn tại"
    return
  fi

  log_info "Tạo .env.fastlane.example..."
  cat > "$env_file" << ENVEOF
# =============================================================================
# Biến môi trường cho Fastlane + App Store Connect
# Sao chép file này thành .env.fastlane và điền giá trị
# QUAN TRỌNG: Không commit .env.fastlane lên git!
# =============================================================================

# ── App Store Connect API Key ─────────────────────────────────────────────────
# Lấy tại: https://appstoreconnect.apple.com → Users → Keys
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Nội dung file .p8 encode base64 (dùng cho CI/CD secrets)
# Tạo bằng: base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
ASC_PRIVATE_KEY_CONTENT=LS0tLS1CRUdJTi...

# Hoặc chỉ path đến file .p8 nếu chạy local
# ASC_PRIVATE_KEY_PATH=fastlane/asc_private_key.p8

# ── Apple Developer Account ───────────────────────────────────────────────────
APPLE_ID=your-apple-id@example.com
APPLE_TEAM_ID=XXXXXXXXXX
ITC_TEAM_ID=XXXXXXXXXX

# ── App Info ──────────────────────────────────────────────────────────────────
APP_BUNDLE_ID=${APP_ID}
APP_NAME=${APP_NAME}
APP_VERSION=1.0.0
APP_SKU=${APP_ID}-001
APP_LANGUAGE=${FL_APP_LANGUAGE}

# ── Match (Code Signing) ──────────────────────────────────────────────────────
# Private git repo để lưu certificates và provisioning profiles
MATCH_GIT_URL=git@github.com:your-org/your-app-certs.git
MATCH_GIT_BRANCH=main
MATCH_PASSWORD=your-match-password
MATCH_TYPE=appstore

# ── Build ─────────────────────────────────────────────────────────────────────
IOS_SCHEME=App
BUILD_CONFIG=Release
RELEASE_NOTES=Phiên bản mới
BETA_FEEDBACK_EMAIL=your-apple-id@example.com

# ── Notifications (tuỳ chọn) ─────────────────────────────────────────────────
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx/yyy/zzz

# ── CI/CD Flags ───────────────────────────────────────────────────────────────
# SKIP_ASC_SETUP=false   # true → bỏ qua create_bundle_id + create_app
# SKIP_BUILD=false       # true → bỏ qua gym build
# SKIP_UPLOAD=false      # true → bỏ qua upload TestFlight
ENVEOF
  log_ok ".env.fastlane.example đã được tạo"

  # Đảm bảo .env.fastlane được gitignore
  local gitignore="${PROJECT_ROOT}/.gitignore"
  if [[ -f "$gitignore" ]] && ! grep -q ".env.fastlane$" "$gitignore"; then
    echo -e "\n# Fastlane secrets\n.env.fastlane\nfastlane/asc_private_key.p8\nfastlane/bundle_id_result.json" >> "$gitignore"
    log_ok ".gitignore đã được cập nhật (thêm Fastlane secrets)"
  fi
}

# ----------------------------------------------------------------------------- 
# Chạy bundle install
# ----------------------------------------------------------------------------- 
run_bundle_install() {
  log_section "Bundle Install (cài Fastlane gems)"
  cd "$PROJECT_ROOT"

  if bundle check &>/dev/null 2>&1; then
    log_ok "Gems đã được cài đầy đủ"
    return
  fi

  log_info "Đang chạy bundle install..."
  # --jobs=4 để cài song song, --retry=3 để retry khi mạng yếu
  bundle install --jobs=4 --retry=3
  log_ok "bundle install hoàn tất"
}

# ----------------------------------------------------------------------------- 
# Hàm tổng: setup_fastlane
# Gọi sau khi add_platforms() và sync_capacitor() đã xong
# ----------------------------------------------------------------------------- 
setup_fastlane() {
  if [[ "${SKIP_FASTLANE}" == "true" ]]; then
    log_warn "SKIP_FASTLANE=true → Bỏ qua cài đặt Fastlane"
    return
  fi

  # Chỉ chạy nếu có ít nhất 1 platform đã được add
  local has_platform=false
  if [[ -d "${PROJECT_ROOT}/ios" ]] || [[ -d "${PROJECT_ROOT}/android" ]]; then
    has_platform=true
  fi

  if [[ "$has_platform" == "false" ]] && [[ -z "$PLATFORMS" ]]; then
    log_warn "Không có platform nào được add → Bỏ qua Fastlane setup"
    log_info "Thêm CAP_PLATFORMS=\"ios\" hoặc \"android\" để kích hoạt Fastlane"
    return
  fi

  log_section "Fastlane Setup"

  # Kiểm tra Ruby
  if ! check_ruby; then
    log_warn "Bỏ qua Fastlane (Ruby chưa được cài)"
    return
  fi

  # Tạo các file cấu hình
  create_gemfile
  create_appfile
  create_asc_action
  create_fastfile
  create_env_example

  # Cài gems
  run_bundle_install

  log_ok "Fastlane setup hoàn tất!"
  log_info "Dùng: bundle exec fastlane <lane>"
  log_info "Ví dụ: bundle exec fastlane full_setup"
}

# ----------------------------------------------------------------------------- 
# Tóm tắt
# ----------------------------------------------------------------------------- 
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║      ✅ CAPACITOR + FASTLANE SETUP HOÀN TẤT     ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${BOLD}Các thay đổi đã thực hiện:${RESET}"
  echo -e "  ${GREEN}✓${RESET} Router: createBrowserRouter → createHashRouter"
  echo -e "  ${GREEN}✓${RESET} Vite: thêm base: './'"
  echo -e "  ${GREEN}✓${RESET} index.html: xóa script sandbox VibEx"
  echo -e "  ${GREEN}✓${RESET} capacitor.config.json đã được tạo/cập nhật"
  echo -e "  ${GREEN}✓${RESET} Web app đã được build"
  echo -e "  ${GREEN}✓${RESET} Capacitor sync hoàn tất"
  if [[ "${SKIP_FASTLANE}" != "true" ]]; then
    echo -e "  ${GREEN}✓${RESET} Fastlane: Gemfile, Fastfile, custom action ASC API"
    echo -e "  ${GREEN}✓${RESET} .env.fastlane.example đã được tạo"
    echo -e "  ${GREEN}✓${RESET} bundle install hoàn tất"
  fi
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
  if [[ "${SKIP_FASTLANE}" != "true" ]]; then
    echo ""
    echo -e "${BOLD}Fastlane:${RESET}"
    echo -e "  ${CYAN}1.${RESET} Sao chép và điền thông tin:"
    echo -e "     cp .env.fastlane.example .env.fastlane"
    echo -e "  ${CYAN}2.${RESET} Tạo Bundle ID + App trên Apple:"
    echo -e "     bundle exec fastlane full_setup"
    echo -e "  ${CYAN}3.${RESET} Hoặc chạy từng bước:"
    echo -e "     bundle exec fastlane create_bundle_id"
    echo -e "     bundle exec fastlane create_app"
    echo -e "  ${CYAN}4.${RESET} CI/CD pipeline tự động:"
    echo -e "     bundle exec fastlane ci_pipeline"
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

  # --- Fastlane: chạy SAU KHI platforms đã được add ---
  setup_fastlane

  print_summary
}

main "$@"
