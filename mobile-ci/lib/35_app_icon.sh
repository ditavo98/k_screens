#!/usr/bin/env bash
# lib/35_app_icon.sh — Generate app icon cho iOS và Android
#
# Biến vào:
#   APP_ICON         (tuỳ chọn) — URL http(s) hoặc đường dẫn file PNG ≥ 1024x1024.
#                                Để trống → tự động đọc <link rel="icon" href="...">
#                                trong project/index.html.
#   INDEX_HTML_PATH  (tuỳ chọn) — đường dẫn index.html (mặc định ${PROJECT_ROOT}/index.html)
#   PROJECT_ROOT     thư mục gốc project Capacitor
#   CONFIG_FILE      đường dẫn mobile.config.sh (để resolve APP_ICON tương đối)
#
# Cách hoạt động:
#   1. Gọi prepare-icon.js → tự extract URL từ index.html (hoặc dùng APP_ICON),
#      download/copy về ${PROJECT_ROOT}/resources/icon.png.
#   2. Chạy npx @capacitor/assets generate.

apply_app_icon() {
  log_section "Generate App Icon"

  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local prepare_js="${script_dir}/prepare-icon.js"

  if [[ ! -f "$prepare_js" ]]; then
    log_error "Không tìm thấy ${prepare_js}"
    return 1
  fi

  if ! command -v node &>/dev/null; then
    log_error "Cần Node.js để chuẩn bị icon (gọi prepare-icon.js)"
    return 1
  fi

  local config_dir=""
  if [[ -n "${CONFIG_FILE:-}" ]]; then
    config_dir="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
  fi

  # prepare-icon.js sẽ ghi vào ${PROJECT_ROOT}/resources/icon.png
  if ! PROJECT_ROOT="${PROJECT_ROOT}" \
       APP_ICON="${APP_ICON:-}" \
       INDEX_HTML_PATH="${INDEX_HTML_PATH:-}" \
       CONFIG_DIR="${config_dir}" \
       node "$prepare_js"; then
    log_error "Chuẩn bị icon thất bại"
    return 1
  fi

  local icon_out="${PROJECT_ROOT}/resources/icon.png"
  if [[ ! -s "$icon_out" ]]; then
    log_error "Không có file ${icon_out} sau khi chạy prepare-icon.js"
    return 1
  fi

  # Cảnh báo kích thước nếu có sips (macOS)
  if command -v sips &>/dev/null; then
    local w h
    w=$(sips -g pixelWidth "$icon_out" 2>/dev/null | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$icon_out" 2>/dev/null | awk '/pixelHeight/{print $2}')
    if [[ -n "$w" ]] && [[ "$w" -lt 1024 || "$h" -lt 1024 ]]; then
      log_warn "Icon ${w}x${h} — khuyến nghị ≥ 1024x1024"
    fi
  fi

  cd "${PROJECT_ROOT}"
  log_info "Chạy @capacitor/assets generate..."

  # Chỉ generate cho platform có trong PLATFORMS — tránh đụng folder partial.
  # @capacitor/assets nhận flag --ios / --android để giới hạn.
  local platform_flags=""
  for p in ${PLATFORMS:-}; do
    case "$p" in
      ios|android) platform_flags="${platform_flags} --${p}" ;;
    esac
  done

  local bg="${CAP_SPLASH_BG:-#ffffff}"
  local cap_args="--iconBackgroundColor ${bg} --iconBackgroundColorDark ${bg}${platform_flags}"

  npx --yes @capacitor/assets generate $cap_args 2>&1 || \
    npx --yes @capacitor/assets generate $platform_flags 2>&1 || \
    true  # exit code 0 không tin được — verify bằng output file

  # Verify thật sự có file icon được sinh ra cho mỗi platform yêu cầu.
  # @capacitor/assets có thể exit 0 ngay cả khi sharp không đọc được source
  # (vd. file ICO/SVG) — chỉ log "No assets found" rồi thoát.
  local any_generated=0
  local missing=()
  for p in ${PLATFORMS:-}; do
    case "$p" in
      ios)
        local ios_icon_dir="${PROJECT_ROOT}/ios/App/App/Assets.xcassets/AppIcon.appiconset"
        if compgen -G "${ios_icon_dir}/*.png" > /dev/null; then
          log_ok "  → iOS:     ${ios_icon_dir#${PROJECT_ROOT}/}/"
          any_generated=1
        else
          missing+=("ios (${ios_icon_dir#${PROJECT_ROOT}/})")
        fi
        ;;
      android)
        local and_icon_dir="${PROJECT_ROOT}/android/app/src/main/res"
        if compgen -G "${and_icon_dir}/mipmap-*/ic_launcher*.png" > /dev/null; then
          log_ok "  → Android: ${and_icon_dir#${PROJECT_ROOT}/}/mipmap-*/"
          any_generated=1
        else
          missing+=("android (${and_icon_dir#${PROJECT_ROOT}/}/mipmap-*)")
        fi
        ;;
    esac
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Generate icon thất bại — thiếu output cho: ${missing[*]}"
    log_error "Source icon (${icon_out}) có thể không phải PNG hợp lệ cho sharp/libvips."
    log_error "Kiểm tra: \`file ${icon_out}\` — nếu là ICO/SVG, cần cung cấp PNG/JPEG riêng."
    return 1
  fi

  if [[ "$any_generated" == "1" ]]; then
    log_ok "App icon đã được generate thành công!"
  fi
}
