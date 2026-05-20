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

  # Nếu không có password (keystore đã tồn tại từ trước)
  # → dùng env var hoặc placeholder
  if [[ -z "$password" ]]; then
    password="${KEYSTORE_PASSWORD:-CHANGE_ME}"
  fi

  log_info "Tạo keystore.properties..."
  cat > "$props_file" << EOF
# Android Release Keystore Properties
# Tạo bởi mobile-ci
#
# ⚠️ KHÔNG commit file này nếu chứa password thật!
# Trên CI/CD: dùng env vars KEYSTORE_PASSWORD, KEYSTORE_ALIAS
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

  # Kiểm tra đã cấu hình chưa
  if grep -q "keystore.properties" "$gradle_file"; then
    log_ok "Gradle signing đã được cấu hình"
    return
  fi

  log_info "Cấu hình Gradle signing config..."
  backup_file "$gradle_file"

  # Dùng Node.js để sửa build.gradle (cross-platform safe)
  node -e "
    const fs = require('fs');
    let content = fs.readFileSync('${gradle_file}', 'utf8');

    // 1. Thêm block đọc keystore.properties TRƯỚC android {
    const keystoreBlock = \`
// ── Release Keystore (mobile-ci) ──────────────────────────────────
def keystorePropertiesFile = rootProject.file('keystore.properties')
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
} else {
    // Fallback cho CI/CD: đọc từ env vars
    keystoreProperties['storeFile'] = System.getenv('KEYSTORE_STORE_FILE') ?: 'release-keystore.jks'
    keystoreProperties['storePassword'] = System.getenv('KEYSTORE_PASSWORD') ?: ''
    keystoreProperties['keyAlias'] = System.getenv('KEYSTORE_ALIAS') ?: 'release'
    keystoreProperties['keyPassword'] = System.getenv('KEYSTORE_PASSWORD') ?: ''
}
\`;

    // Chèn trước 'android {'
    content = content.replace(
      /^(android\s*\{)/m,
      keystoreBlock + '\n\$1'
    );

    // 2. Thêm signingConfigs block sau 'android {'
    const signingBlock = \`
    signingConfigs {
        release {
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
        }
    }
\`;

    // Tìm buildTypes block và thêm signingConfigs trước nó
    if (content.includes('buildTypes')) {
      content = content.replace(
        /(\s*buildTypes\s*\{)/,
        signingBlock + '\$1'
      );
    } else {
      // Nếu không có buildTypes, thêm sau 'android {'
      content = content.replace(
        /(android\s*\{)/,
        '\$1\n' + signingBlock
      );
    }

    // 3. Cấu hình release buildType dùng signingConfig
    if (!content.includes('signingConfig signingConfigs.release')) {
      content = content.replace(
        /(release\s*\{[^}]*)(})/,
        '\$1    signingConfig signingConfigs.release\n        \$2'
      );
    }

    fs.writeFileSync('${gradle_file}', content);
    process.stdout.write('done');
  "

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

  # Build APK
  log_info "Building release APK..."
  ./gradlew assembleRelease
  log_ok "Release APK build thành công"

  # Build AAB
  log_info "Building release AAB..."
  ./gradlew bundleRelease
  log_ok "Release AAB build thành công"

  # Copy outputs ra thư mục build/
  local build_out="${PROJECT_ROOT}/build"
  mkdir -p "$build_out"

  local apk_path
  apk_path=$(find "${PROJECT_ROOT}/android/app/build/outputs/apk/release" \
    -name "*.apk" -type f 2>/dev/null | head -1)
  local aab_path
  aab_path=$(find "${PROJECT_ROOT}/android/app/build/outputs/bundle/release" \
    -name "*.aab" -type f 2>/dev/null | head -1)

  if [[ -n "$apk_path" ]]; then
    cp "$apk_path" "${build_out}/app-release.apk"
    log_ok "APK → build/app-release.apk"
  fi

  if [[ -n "$aab_path" ]]; then
    cp "$aab_path" "${build_out}/app-release.aab"
    log_ok "AAB → build/app-release.aab"
  fi

  cd "$PROJECT_ROOT"
}
