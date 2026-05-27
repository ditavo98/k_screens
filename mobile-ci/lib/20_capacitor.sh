#!/usr/bin/env bash
# lib/20_capacitor.sh — Cài đặt và cấu hình Capacitor
#
# Biến đầu vào (từ project config):
#   PROJECT_ROOT, APP_NAME, APP_ID, WEB_DIR
#   BUILD_CMD, PACKAGE_MANAGER, PLATFORMS

# --------------------------------------------------------------------------- #
# Cài @capacitor/core + @capacitor/cli
# --------------------------------------------------------------------------- #
install_capacitor() {
  log_section "Cài đặt Capacitor"

  # Core + CLI
  ensure_pkg_installed "@capacitor/core"  false || return 1
  ensure_pkg_installed "@capacitor/cli"   true  || return 1
  log_ok "@capacitor/core + @capacitor/cli sẵn sàng"

  # Platform packages
  for platform in ${PLATFORMS:-}; do
    case "$platform" in
      ios|android)
        ensure_pkg_installed "@capacitor/${platform}" false || return 1
        log_ok "@capacitor/${platform} sẵn sàng"
        ;;
      *)
        log_warn "Platform không hỗ trợ: $platform"
        ;;
    esac
  done
}

# --------------------------------------------------------------------------- #
# Tạo capacitor.config.json
# --------------------------------------------------------------------------- #
create_capacitor_config() {
  log_section "Tạo capacitor.config.json"
  local cfg="${PROJECT_ROOT}/capacitor.config.json"

  if [[ -f "$cfg" ]]; then
    backup_file "$cfg"
    CFG_PATH="$cfg" WEB_DIR_V="$WEB_DIR" ALLOW_NAV="${CAP_ALLOW_NAVIGATION:-}" node -e "
      const fs=require('fs');
      const p=process.env.CFG_PATH;
      const c=JSON.parse(fs.readFileSync(p,'utf8'));
      c.webDir=process.env.WEB_DIR_V;
      c.server=c.server||{};
      c.server.androidScheme='https';
      if(process.env.ALLOW_NAV){
        c.server.allowNavigation=process.env.ALLOW_NAV.split(',').map(s=>s.trim()).filter(Boolean);
      }
      c.plugins=c.plugins||{};
      c.plugins.CapacitorHttp={enabled:true};
      fs.writeFileSync(p,JSON.stringify(c,null,2));
    "
    log_ok "capacitor.config.json đã được patch (webDir, allowNavigation, CapacitorHttp)"
    return
  fi

  # Đọc ALLOW_NAVIGATION nếu có (danh sách domain, phân cách bởi dấu phẩy)
  local allow_nav_json="[]"
  if [[ -n "${CAP_ALLOW_NAVIGATION:-}" ]]; then
    allow_nav_json=$(node -e "
      const domains='${CAP_ALLOW_NAVIGATION}'.split(',').map(d=>d.trim());
      process.stdout.write(JSON.stringify(domains));
    ")
  fi

  cat > "$cfg" << EOF
{
  "appId": "${APP_ID}",
  "appName": "${APP_NAME}",
  "webDir": "${WEB_DIR}",
  "server": {
    "androidScheme": "https",
    "allowNavigation": ${allow_nav_json}
  },
  "plugins": {
    "CapacitorHttp": {
      "enabled": true
    },
    "SplashScreen": {
      "launchShowDuration": 2000,
      "launchAutoHide": true,
      "backgroundColor": "${CAP_SPLASH_BG:-#ffffff}",
      "showSpinner": false
    },
    "StatusBar": {
      "style": "${CAP_STATUS_BAR_STYLE:-Default}",
      "backgroundColor": "${CAP_STATUS_BAR_BG:-#ffffff}"
    }
  },
  "ios": {
    "scheme": "${IOS_SCHEME:-App}"
  },
  "android": {
    "allowMixedContent": true,
    "captureInput": true
  }
}
EOF
  log_ok "capacitor.config.json đã được tạo"
}

# --------------------------------------------------------------------------- #
# Build web app
# --------------------------------------------------------------------------- #
build_web() {
  log_section "Build web app"
  cd "$PROJECT_ROOT"

  # Auto-detect build command
  local cmd="${BUILD_CMD:-}"
  if [[ -z "$cmd" ]]; then
    case "${PACKAGE_MANAGER:-npm}" in
      pnpm) cmd="pnpm run build" ;;
      yarn) cmd="yarn build"     ;;
      *)    cmd="npm run build"  ;;
    esac
  fi

  log_info "Chạy: $cmd"
  eval "$cmd"

  if [[ ! -d "${PROJECT_ROOT}/${WEB_DIR}" ]]; then
    log_error "Thư mục '${WEB_DIR}' không tồn tại sau khi build!"
    exit 1
  fi
  log_ok "Build thành công → ${WEB_DIR}/"
}

# --------------------------------------------------------------------------- #
# Khởi tạo Capacitor (cap init)
# --------------------------------------------------------------------------- #
init_capacitor() {
  log_section "Khởi tạo Capacitor"
  cd "$PROJECT_ROOT"

  # Nếu chưa có ios/ hoặc android/ → cần init
  if [[ ! -d "${PROJECT_ROOT}/ios" ]] && [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_info "Chạy cap init..."
    npx cap init \
      "${APP_NAME}" \
      "${APP_ID}" \
      --web-dir "${WEB_DIR}" || log_warn "cap init có cảnh báo, tiếp tục..."
  else
    log_ok "Capacitor đã được init (platform dirs tồn tại)"
  fi
}

# --------------------------------------------------------------------------- #
# Add platforms (ios / android)
# --------------------------------------------------------------------------- #
add_platforms() {
  log_section "Add Platforms"
  cd "$PROJECT_ROOT"

  if [[ -z "${PLATFORMS:-}" ]]; then
    log_skip "PLATFORMS chưa được đặt, bỏ qua"
    return
  fi

  for platform in ${PLATFORMS}; do
    if [[ -d "${PROJECT_ROOT}/${platform}" ]]; then
      log_ok "Platform '${platform}' đã tồn tại"
    else
      log_info "Thêm platform: ${platform}"
      npx cap add "$platform"
      log_ok "Đã thêm platform: ${platform}"
    fi
  done
}

# --------------------------------------------------------------------------- #
# Capacitor sync
# --------------------------------------------------------------------------- #
sync_capacitor() {
  log_section "Capacitor Sync"
  cd "$PROJECT_ROOT"

  # Verify lại platform packages — bảo vệ trường hợp:
  #   • node_modules bị clean giữa install_capacitor và sync (CI cache flow)
  #   • pkg_add fail im lặng trên runner (frozen lockfile, workspace mismatch...)
  for platform in ${PLATFORMS:-}; do
    case "$platform" in
      ios|android)
        if ! pkg_installed "@capacitor/${platform}"; then
          log_warn "node_modules/@capacitor/${platform}/ thiếu trước cap sync — cài lại"
          ensure_pkg_installed "@capacitor/${platform}" false || return 1
        fi
        ;;
    esac
  done

  npx cap sync
  log_ok "cap sync hoàn tất"
}

# --------------------------------------------------------------------------- #
# Hàm tổng: chạy full Capacitor setup
# --------------------------------------------------------------------------- #
run_capacitor_setup() {
  install_capacitor
  create_capacitor_config
  build_web
  init_capacitor
  add_platforms
  sync_capacitor
}
