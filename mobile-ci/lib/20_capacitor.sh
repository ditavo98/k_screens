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
# Kiểm tra platform folder có scaffold đầy đủ chưa
# (phân biệt với folder rỗng / chỉ có keystore committed)
# --------------------------------------------------------------------------- #
_platform_is_scaffolded() {
  local platform="$1"
  local dir="${PROJECT_ROOT}/${platform}"
  [[ -d "$dir" ]] || return 1
  case "$platform" in
    android)
      # cap add android tạo build.gradle + settings.gradle ở root
      [[ -f "${dir}/build.gradle" ]] && [[ -f "${dir}/settings.gradle" ]]
      ;;
    ios)
      # cap add ios tạo App/Podfile + App/App.xcodeproj
      [[ -f "${dir}/App/Podfile" ]] && [[ -d "${dir}/App/App.xcodeproj" ]]
      ;;
    *)
      [[ -d "$dir" ]]
      ;;
  esac
}

# --------------------------------------------------------------------------- #
# Re-scaffold platform khi folder bị partial (vd. chỉ keystore committed).
# Move folder cũ ra tmp → cap add → restore các file user (file scaffold không tạo).
# Idempotent: file mà cap add tạo (build.gradle, etc.) giữ phiên bản mới;
# file user (keystore.properties, release-keystore.jks, ...) được restore.
# --------------------------------------------------------------------------- #
_rebuild_platform_preserving_user_files() {
  local platform="$1"
  local dir="${PROJECT_ROOT}/${platform}"
  local backup_root
  backup_root=$(mktemp -d)
  local saved="${backup_root}/${platform}"

  log_warn "Platform '${platform}' tồn tại nhưng KHÔNG đầy đủ — re-scaffold giữ file user"

  log_info "Backup ${platform}/ → ${saved}"
  if ! mv "$dir" "$saved"; then
    log_error "Không backup được ${dir}"
    rm -rf "$backup_root"
    return 1
  fi

  log_info "Chạy cap add ${platform}"
  if ! ( cd "$PROJECT_ROOT" && npx cap add "$platform" ); then
    log_error "cap add ${platform} thất bại — khôi phục backup"
    rm -rf "$dir"
    mv "$saved" "$dir"
    rm -rf "$backup_root"
    return 1
  fi

  # Restore: chỉ những file scaffold KHÔNG tạo (file user committed: keystore, properties...)
  local restored=0
  while IFS= read -r -d '' src; do
    local rel="${src#${saved}/}"
    local dest="${dir}/${rel}"
    if [[ ! -e "$dest" ]]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      log_info "  + restore ${platform}/${rel}"
      restored=$((restored + 1))
    fi
  done < <(find "$saved" -type f -print0 2>/dev/null)

  log_ok "Đã restore ${restored} file user vào ${platform}/"
  rm -rf "$backup_root"
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
    case "$platform" in
      ios|android) ;;
      *)
        log_warn "Platform không hỗ trợ: $platform"
        continue
        ;;
    esac

    if _platform_is_scaffolded "$platform"; then
      log_ok "Platform '${platform}' đã scaffold đầy đủ"
      continue
    fi

    if [[ -d "${PROJECT_ROOT}/${platform}" ]]; then
      # Folder tồn tại nhưng thiếu scaffold → re-scaffold giữ file user
      _rebuild_platform_preserving_user_files "$platform" || return 1
    else
      log_info "Thêm platform: ${platform}"
      ( cd "$PROJECT_ROOT" && npx cap add "$platform" ) || return 1
    fi
    log_ok "Đã thêm platform: ${platform}"
  done
}

# --------------------------------------------------------------------------- #
# Capacitor sync
# --------------------------------------------------------------------------- #
sync_capacitor() {
  log_section "Capacitor Sync"
  cd "$PROJECT_ROOT"

  if [[ -z "${PLATFORMS:-}" ]]; then
    log_skip "PLATFORMS rỗng — bỏ qua cap sync"
    return
  fi

  # Sync per-platform để khi job chỉ chạy ios (CAP_PLATFORMS=ios) thì
  # KHÔNG đụng vào folder android/ đã committed sẵn trong repo
  # (và ngược lại). `npx cap sync` không arg sẽ sync tất cả platform
  # folder hiện có — gây fail nếu @capacitor/<platform> chưa cài.
  for platform in ${PLATFORMS}; do
    case "$platform" in
      ios|android) ;;
      *)
        log_warn "Bỏ qua platform không hỗ trợ: $platform"
        continue
        ;;
    esac

    # Safety net: verify @capacitor/<platform> còn trong node_modules.
    # Bảo vệ trường hợp node_modules bị clean giữa install và sync.
    if ! pkg_installed "@capacitor/${platform}"; then
      log_warn "node_modules/@capacitor/${platform}/ thiếu trước cap sync — cài lại"
      ensure_pkg_installed "@capacitor/${platform}" false || return 1
    fi

    log_info "Sync platform: ${platform}"
    npx cap sync "${platform}"
  done

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
