#!/usr/bin/env bash
# lib/25_android_keystore.sh — Tạo keystore + cấu hình Gradle signing
#
# Biến đầu vào:
#   PROJECT_ROOT, APP_NAME, APP_ID
#   KEYSTORE_PASSWORD (tùy chọn — tự tạo nếu chưa có)
#   KEYSTORE_ALIAS    (tùy chọn — mặc định "release")

# --------------------------------------------------------------------------- #
# Tạo keystore nếu chưa có
# --------------------------------------------------------------------------- #
setup_android_keystore() {
  if [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_skip "Platform android chưa được add, bỏ qua keystore"
    return
  fi

  log_section "Android Keystore Setup"

  local keystore_dir="${PROJECT_ROOT}/android/app"
  local keystore_file="${keystore_dir}/release-keystore.jks"
  local props_file="${PROJECT_ROOT}/android/keystore.properties"
  local alias="${KEYSTORE_ALIAS:-release}"

  # ── Nếu keystore đã tồn tại → chỉ đảm bảo gradle config ──
  if [[ -f "$keystore_file" ]]; then
    log_ok "Keystore đã tồn tại: release-keystore.jks"
    _ensure_keystore_properties "$props_file" "$alias"
    _ensure_gradle_signing
    return
  fi

  # ── Tạo password nếu chưa có ──
  local password="${KEYSTORE_PASSWORD:-}"
  if [[ -z "$password" ]]; then
    password=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
    log_info "Tạo password ngẫu nhiên cho keystore"
  fi

  # ── Kiểm tra keytool ──
  if ! command -v keytool &>/dev/null; then
    log_error "keytool không tìm thấy. Cài JDK trước."
    return 1
  fi

  # ── CN từ APP_NAME, OU từ APP_ID ──
  local cn="${APP_NAME:-K Screens}"
  local ou="${APP_ID:-com.example.app}"

  log_info "Tạo release keystore..."
  keytool -genkeypair \
    -v \
    -storetype JKS \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$password" \
    -keypass "$password" \
    -alias "$alias" \
    -keystore "$keystore_file" \
    -dname "CN=${cn}, OU=${ou}, O=${cn}, L=Seoul, ST=Seoul, C=KR"

  if [[ ! -f "$keystore_file" ]]; then
    log_error "Tạo keystore thất bại!"
    return 1
  fi

  log_ok "Keystore đã được tạo: release-keystore.jks"

  # ── Tạo keystore.properties ──
  _ensure_keystore_properties "$props_file" "$alias" "$password"

  # ── Cấu hình Gradle ──
  _ensure_gradle_signing

  # ── Tự động commit và push keystore + properties nếu chưa được track ──
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local rel_keystore
    local rel_props
    rel_keystore=$(git ls-files --error-unmatch "$keystore_file" 2>/dev/null || echo "untracked")
    rel_props=$(git ls-files --error-unmatch "$props_file" 2>/dev/null || echo "untracked")

    if [[ "$rel_keystore" == "untracked" ]] || [[ "$rel_props" == "untracked" ]]; then
      log_info "Tự động commit và push keystore mới tạo lên git..."
      
      # Lưu thư mục hiện tại để restore
      local cur_dir
      cur_dir=$(pwd)
      cd "${PROJECT_ROOT}"

      # Thiết lập user nếu chạy trên CI
      if [[ "${CI:-}" == "true" ]]; then
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
      fi

      # Force add vì .gitignore có thể loại bỏ các file .jks hoặc .properties
      git add -f "$keystore_file" "$props_file"
      git commit -m "chore: auto-generate release keystore and properties [skip ci]" || true
      
      # Thử push lên origin HEAD hoặc origin main
      if git push origin HEAD 2>/dev/null || git push origin main 2>/dev/null; then
        log_ok "Đã commit và push keystore lên git thành công!"
      else
        log_warn "Không thể push keystore tự động lên git. Hãy push thủ công."
      fi

      cd "$cur_dir"
    fi
  fi

  # ── In thông tin ──
  echo ""
  log_info "╔══════════════════════════════════════════════════╗"
  log_info "║  ⚠️  LƯU THÔNG TIN KEYSTORE NÀY!              ║"
  log_info "╠══════════════════════════════════════════════════╣"
  log_info "║  File:     android/app/release-keystore.jks     ║"
  log_info "║  Alias:    ${alias}"
  log_info "║  Password: ${password}"
  log_info "║                                                  ║"
  log_info "║  MẤT keystore = KHÔNG THỂ update app!           ║"
  log_info "╚══════════════════════════════════════════════════╝"
  echo ""
}

# --------------------------------------------------------------------------- #
# Tạo/cập nhật keystore.properties
# --------------------------------------------------------------------------- #
_ensure_keystore_properties() {
  local props_file="$1"
  local alias="$2"
  local password="${3:-}"

  if [[ -f "$props_file" ]]; then
    log_ok "keystore.properties đã tồn tại"
    return
  fi

  if [[ -z "$password" ]]; then
    password="${KEYSTORE_PASSWORD:-CHANGE_ME}"
  fi

  log_info "Tạo keystore.properties..."
  cat > "$props_file" << EOF
# Android Release Keystore Properties
# Tạo bởi mobile-ci
storeFile=release-keystore.jks
storePassword=${password}
keyAlias=${alias}
keyPassword=${password}
EOF

  log_ok "keystore.properties đã được tạo"
}

# --------------------------------------------------------------------------- #
# Cấu hình build.gradle để dùng keystore cho release
# --------------------------------------------------------------------------- #
_ensure_gradle_signing() {
  local gradle_file="${PROJECT_ROOT}/android/app/build.gradle"

  if [[ ! -f "$gradle_file" ]]; then
    log_warn "build.gradle không tìm thấy, bỏ qua cấu hình signing"
    return
  fi

  # Nếu đã cấu hình ĐÚNG → skip
  if grep -q "keystoreProperties" "$gradle_file" && \
     grep -A5 "buildTypes" "$gradle_file" | grep -q "signingConfig"; then
    log_ok "Gradle signing đã được cấu hình"
    return
  fi

  log_info "Cấu hình Gradle signing config..."
  backup_file "$gradle_file"

  # Viết Node.js script ra file tạm (tránh lỗi escape shell)
  local tmp_script
  tmp_script=$(mktemp)

  cat > "$tmp_script" << 'NODESCRIPT'
const fs = require('fs');
const gf = process.argv[2];
let c = fs.readFileSync(gf, 'utf8');

// Cleanup: xóa signing config cũ bị sai nếu có
c = c.replace(/\/\/ ── Release Keystore[\s\S]*?^}\n*/m, '');

// 1. Block đọc keystore.properties — chèn TRƯỚC "android {"
if (!c.includes('keystoreProperties')) {
  const kb = [
    '',
    '// ── Release Keystore (mobile-ci) ────────────────────────────',
    'def keystorePropertiesFile = rootProject.file("keystore.properties")',
    'def keystoreProperties = new Properties()',
    'if (keystorePropertiesFile.exists()) {',
    '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))',
    '} else {',
    '    keystoreProperties["storeFile"] = System.getenv("KEYSTORE_STORE_FILE") ?: "release-keystore.jks"',
    '    keystoreProperties["storePassword"] = System.getenv("KEYSTORE_PASSWORD") ?: ""',
    '    keystoreProperties["keyAlias"] = System.getenv("KEYSTORE_ALIAS") ?: "release"',
    '    keystoreProperties["keyPassword"] = System.getenv("KEYSTORE_PASSWORD") ?: ""',
    '}',
    ''
  ].join('\n');
  c = c.replace(/^(android\s*\{)/m, kb + '$1');
}

// 2. signingConfigs block — chèn TRƯỚC "buildTypes {"
if (!c.includes('signingConfigs')) {
  const sb = [
    '',
    '    signingConfigs {',
    '        release {',
    '            storeFile file(keystoreProperties["storeFile"])',
    '            storePassword keystoreProperties["storePassword"]',
    '            keyAlias keystoreProperties["keyAlias"]',
    '            keyPassword keystoreProperties["keyPassword"]',
    '        }',
    '    }',
    ''
  ].join('\n');
  c = c.replace(/(\s*buildTypes\s*\{)/, sb + '$1');
}

// 3. signingConfig — chèn VÀO "buildTypes > release {"
if (!c.includes('signingConfig signingConfigs.release')) {
  const btIdx = c.indexOf('buildTypes');
  if (btIdx !== -1) {
    const after = c.substring(btIdx);
    const m = after.match(/release\s*\{/);
    if (m) {
      const pos = btIdx + m.index + m[0].length;
      c = c.substring(0, pos) +
        '\n            signingConfig signingConfigs.release' +
        c.substring(pos);
    }
  }
}

fs.writeFileSync(gf, c);
console.log('gradle signing configured');
NODESCRIPT

  node "$tmp_script" "$gradle_file"
  rm -f "$tmp_script"

  log_ok "Gradle signing config đã được cấu hình"
}

# --------------------------------------------------------------------------- #
# Build Release APK + AAB
# --------------------------------------------------------------------------- #
build_android_release() {
  if [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_skip "Platform android chưa được add"
    return
  fi

  log_section "Build Android Release"
  cd "${PROJECT_ROOT}/android"

  chmod +x gradlew

  log_info "Building release APK + AAB..."
  ./gradlew assembleRelease bundleRelease
  log_ok "Release build thành công"

  # Copy outputs ra thư mục build/
  local build_out="${PROJECT_ROOT}/build"
  mkdir -p "$build_out"

  local apk_path
  apk_path=$(find "${PROJECT_ROOT}/android/app/build/outputs/apk/release" \
    -name "*.apk" -type f 2>/dev/null | head -1)
  local aab_path
  aab_path=$(find "${PROJECT_ROOT}/android/app/build/outputs/bundle/release" \
    -name "*.aab" -type f 2>/dev/null | head -1)

  [[ -n "$apk_path" ]] && cp "$apk_path" "${build_out}/app-release.apk" && log_ok "APK → build/app-release.apk"
  [[ -n "$aab_path" ]] && cp "$aab_path" "${build_out}/app-release.aab" && log_ok "AAB → build/app-release.aab"

  cd "$PROJECT_ROOT"
}
