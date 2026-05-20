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
# Hàm tổng
# --------------------------------------------------------------------------- #
run_platform_fixes() {
  fix_ios_transport
  fix_android_network
}
