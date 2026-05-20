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

  if pkg_installed "@capacitor/core"; then
    log_ok "@capacitor/core đã được cài"
  else
    log_info "Cài @capacitor/core..."
    pkg_add false @capacitor/core
    pkg_add true  @capacitor/cli
    log_ok "@capacitor/core + @capacitor/cli đã được cài"
  fi

  # Cài platform packages
  for platform in ${PLATFORMS:-}; do
    case "$platform" in
      ios)
        if pkg_installed "@capacitor/ios"; then
          log_ok "@capacitor/ios đã được cài"
        else
          log_info "Cài @capacitor/ios..."
          pkg_add false @capacitor/ios
        fi
        ;;
      android)
        if pkg_installed "@capacitor/android"; then
          log_ok "@capacitor/android đã được cài"
        else
          log_info "Cài @capacitor/android..."
          pkg_add false @capacitor/android
        fi
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
    local cur_dir
    cur_dir=$(node -e "try{const c=require('${cfg}');process.stdout.write(c.webDir||'')}catch(e){}" 2>/dev/null)
    if [[ "$cur_dir" != "${WEB_DIR}" ]]; then
      log_warn "webDir hiện tại '${cur_dir}' ≠ '${WEB_DIR}', đang cập nhật..."
      backup_file "$cfg"
      node -e "
        const fs=require('fs');
        const c=JSON.parse(fs.readFileSync('${cfg}','utf8'));
        c.webDir='${WEB_DIR}';
        fs.writeFileSync('${cfg}',JSON.stringify(c,null,2));
      "
    else
      log_ok "capacitor.config.json đã đúng"
    fi
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
