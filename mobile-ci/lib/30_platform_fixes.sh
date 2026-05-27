#!/usr/bin/env bash
# lib/30_platform_fixes.sh — Fix iOS và Android specific issues

# --------------------------------------------------------------------------- #
# iOS: NSAppTransportSecurity trong Info.plist
# --------------------------------------------------------------------------- #
fix_ios_transport() {
  local plist="${PROJECT_ROOT}/ios/App/App/Info.plist"

  if [[ ! -f "$plist" ]]; then
    log_skip "Info.plist chưa có (iOS chưa được add)"
    return
  fi

  log_section "Fix iOS NSAppTransportSecurity"

  if grep -q "NSAllowsArbitraryLoads" "$plist"; then
    log_ok "NSAppTransportSecurity đã được cấu hình"
    return
  fi

  backup_file "$plist"
  # Đảm bảo python3 có sẵn (CI/CD có thể chưa cài)
  ensure_cmd python3 || { log_warn "Bỏ qua fix iOS ATS (python3 không có)"; return; }
  # Truyền PLIST_PATH qua inline env để python3 subprocess nhận được
  PLIST_PATH="$plist" python3 - << 'PYEOF'
import plistlib, os, sys
path = os.environ['PLIST_PATH']
with open(path, 'rb') as f:
    plist = plistlib.load(f)
if 'NSAppTransportSecurity' not in plist:
    plist['NSAppTransportSecurity'] = {
        'NSAllowsArbitraryLoads': True,
        'NSAllowsArbitraryLoadsInWebContent': True,
    }
    with open(path, 'wb') as f:
        plistlib.dump(plist, f)
    print(f'Updated {path}')
else:
    print('NSAppTransportSecurity already configured')
PYEOF
  log_ok "iOS NSAppTransportSecurity đã được cấu hình"
}

# --------------------------------------------------------------------------- #
# iOS: ITSAppUsesNonExemptEncryption = false trong Info.plist
# (tránh câu hỏi export compliance mỗi lần submit lên App Store Connect)
# --------------------------------------------------------------------------- #
fix_ios_encryption() {
  local plist="${PROJECT_ROOT}/ios/App/App/Info.plist"

  if [[ ! -f "$plist" ]]; then
    log_skip "Info.plist chưa có (iOS chưa được add)"
    return
  fi

  log_section "Fix iOS ITSAppUsesNonExemptEncryption"

  ensure_cmd python3 || { log_warn "Bỏ qua (python3 không có)"; return; }

  PLIST_PATH="$plist" python3 - << 'PYEOF'
import plistlib, os
path = os.environ['PLIST_PATH']
with open(path, 'rb') as f:
    plist = plistlib.load(f)
if plist.get('ITSAppUsesNonExemptEncryption') is False:
    print('ITSAppUsesNonExemptEncryption already set to false')
else:
    plist['ITSAppUsesNonExemptEncryption'] = False
    with open(path, 'wb') as f:
        plistlib.dump(plist, f)
    print(f'Set ITSAppUsesNonExemptEncryption = false in {path}')
PYEOF
  log_ok "ITSAppUsesNonExemptEncryption đã được set false"
}

# --------------------------------------------------------------------------- #
# Android: network_security_config.xml + AndroidManifest.xml
# --------------------------------------------------------------------------- #
fix_android_network() {
  if [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_skip "Platform android chưa được add"
    return
  fi

  log_section "Fix Android Network Security"

  local xml_dir="${PROJECT_ROOT}/android/app/src/main/res/xml"
  local net_cfg="${xml_dir}/network_security_config.xml"
  local manifest="${PROJECT_ROOT}/android/app/src/main/AndroidManifest.xml"

  mkdir -p "$xml_dir"

  if [[ ! -f "$net_cfg" ]]; then
    cat > "$net_cfg" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Cho phép cleartext với localhost (dev) -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
    <!-- Mọi domain khác phải dùng HTTPS -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
EOF
    log_ok "network_security_config.xml đã được tạo"
  else
    log_ok "network_security_config.xml đã tồn tại"
  fi

  if [[ -f "$manifest" ]] && ! grep -q "networkSecurityConfig" "$manifest"; then
    backup_file "$manifest"
    node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${manifest}', 'utf8');
      c = c.replace(
        /(<application)/,
        '\$1\n        android:networkSecurityConfig=\"@xml/network_security_config\"'
      );
      fs.writeFileSync('${manifest}', c);
    "
    log_ok "AndroidManifest.xml đã được cập nhật"
  fi
}

# --------------------------------------------------------------------------- #
# Cập nhật APP_VERSION vào package.json, Android build.gradle và iOS pbxproj
# --------------------------------------------------------------------------- #
apply_app_version() {
  log_section "Cấu hình App Version: ${APP_VERSION}"

  # 1. Cập nhật package.json
  local pkg_json="${PROJECT_ROOT}/package.json"
  if [[ -f "$pkg_json" ]]; then
    backup_file "$pkg_json"
    APP_VERSION="${APP_VERSION}" node -e "
      const fs = require('fs');
      const pkg = JSON.parse(fs.readFileSync('${pkg_json}', 'utf8'));
      pkg.version = process.env.APP_VERSION;
      fs.writeFileSync('${pkg_json}', JSON.stringify(pkg, null, 2) + '\n');
    "
    log_ok "Đã cập nhật version '${APP_VERSION}' vào package.json"
  else
    log_warn "Không tìm thấy package.json tại ${PROJECT_ROOT}"
  fi

  # 2. Cập nhật Android (android/app/build.gradle)
  local build_gradle="${PROJECT_ROOT}/android/app/build.gradle"
  if [[ -f "$build_gradle" ]]; then
    backup_file "$build_gradle"
    APP_VERSION="${APP_VERSION}" node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${build_gradle}', 'utf8');
      
      // Tính toán versionCode từ SemVer (ví dụ 1.2.3 -> 10203)
      const parts = process.env.APP_VERSION.split('.').map(Number);
      const major = parts[0] || 0;
      const minor = parts[1] || 0;
      const patch = parts[2] || 0;
      const code = major * 10000 + minor * 100 + patch;
      
      c = c.replace(/versionName\s+\"[^\"]*\"/g, 'versionName \"' + process.env.APP_VERSION + '\"');
      c = c.replace(/versionCode\s+\d+/g, 'versionCode ' + code);
      fs.writeFileSync('${build_gradle}', c);
      console.log('Android versionCode set to ' + code);
    "
    log_ok "Đã cập nhật Android build.gradle: versionName='${APP_VERSION}'"
  fi

  # 3. Cập nhật iOS (ios/App/App.xcodeproj/project.pbxproj)
  local pbxproj="${PROJECT_ROOT}/ios/App/App.xcodeproj/project.pbxproj"
  if [[ -f "$pbxproj" ]]; then
    backup_file "$pbxproj"
    APP_VERSION="${APP_VERSION}" node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${pbxproj}', 'utf8');
      c = c.replace(/MARKETING_VERSION\s*=\s*[^;]+/g, 'MARKETING_VERSION = ' + process.env.APP_VERSION);
      fs.writeFileSync('${pbxproj}', c);
    "
    log_ok "Đã cập nhật iOS project.pbxproj: MARKETING_VERSION='${APP_VERSION}'"
  fi
}

# --------------------------------------------------------------------------- #
# Hàm tổng
# --------------------------------------------------------------------------- #
run_platform_fixes() {
  fix_ios_transport
  fix_ios_encryption
  fix_android_network
  apply_app_version
  apply_app_icon
}
