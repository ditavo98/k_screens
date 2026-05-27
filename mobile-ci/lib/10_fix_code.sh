#!/usr/bin/env bash
# lib/10_fix_code.sh — Fix các lỗi code phổ biến khi build mobile
#
# Biến đầu vào (từ project config):
#   PROJECT_ROOT, APP_JSX_PATH, VITE_CONFIG_PATH, INDEX_HTML_PATH
#   BACKUP_SUFFIX

# --------------------------------------------------------------------------- #
# Fix Router: createBrowserRouter → createHashRouter
# Lý do: Capacitor chạy file:// nên history API không hoạt động
# --------------------------------------------------------------------------- #
fix_router() {
  local jsx="${APP_JSX_PATH:-${PROJECT_ROOT}/src/App.jsx}"

  log_section "Fix Router (BrowserRouter → HashRouter)"

  if [[ ! -f "$jsx" ]]; then
    log_skip "Không tìm thấy: $jsx"
    return
  fi

  if grep -q "createHashRouter" "$jsx"; then
    log_ok "createHashRouter đã được dùng"
    return
  fi

  if ! grep -q "createBrowserRouter" "$jsx"; then
    log_skip "createBrowserRouter không có trong $(basename "$jsx")"
    return
  fi

  backup_file "$jsx"
  node -e "
    const fs = require('fs');
    let c = fs.readFileSync('${jsx}', 'utf8');
    c = c.replace(/\bcreateBrowserRouter\b/g, 'createHashRouter');
    // Thêm comment giải thích
    c = c.replace(
      /(const router = createHashRouter)/,
      '// mobile-ci: HashRouter bắt buộc cho Capacitor (file:// protocol)\n\$1'
    );
    fs.writeFileSync('${jsx}', c);
  "
  log_ok "createBrowserRouter → createHashRouter ($(basename "$jsx"))"
}

# --------------------------------------------------------------------------- #
# Fix Vite config: thêm base: './'
# Lý do: Assets phải dùng relative path khi load từ file://
# --------------------------------------------------------------------------- #
fix_vite_config() {
  local cfg="${VITE_CONFIG_PATH:-${PROJECT_ROOT}/vite.config.js}"

  log_section "Fix Vite config (base: './')"

  if [[ ! -f "$cfg" ]]; then
    log_skip "Không tìm thấy: $cfg"
    return
  fi

  # Kiểm tra đã có base chưa
  if grep -qE "base:\s*['\"]\./" "$cfg"; then
    log_ok "base: './' đã có trong $(basename "$cfg")"
    return
  fi

  backup_file "$cfg"

  if grep -q "base:" "$cfg"; then
    # Có base nhưng giá trị khác → cập nhật
    node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${cfg}', 'utf8');
      c = c.replace(/base:\s*['\"]\//g, \"base: './\");
      fs.writeFileSync('${cfg}', c);
    "
    log_ok "base đã được cập nhật thành './'"
  else
    # Chưa có base → chèn vào sau 'return {'
    node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${cfg}', 'utf8');
      const m = c.match(/return\s*\{/);
      if (!m) { console.error('Không tìm thấy return { trong vite.config'); process.exit(1); }
      const idx = c.indexOf(m[0]) + m[0].length;
      c = c.slice(0, idx) +
          \"\n    // mobile-ci: base path cho Capacitor native build\n    base: './',\" +
          c.slice(idx);
      fs.writeFileSync('${cfg}', c);
    "
    log_ok "base: './' đã được thêm vào $(basename "$cfg")"
  fi
}

# --------------------------------------------------------------------------- #
# Fix index.html
#   1. Xóa script sandbox (dev-cdn.vibe-x.app hoặc tên domain tùy config)
#   2. Thêm meta CSP cho capacitor://
# --------------------------------------------------------------------------- #
fix_index_html() {
  local html="${INDEX_HTML_PATH:-${PROJECT_ROOT}/index.html}"
  # SANDBOX_SCRIPT_DOMAINS: danh sách domain cần xóa, phân cách bởi |
  # Ví dụ: "dev-cdn.vibe-x.app|sandbox.example.com"
  local domains="${SANDBOX_SCRIPT_DOMAINS:-dev-cdn.vibe-x.app}"

  log_section "Fix index.html (xóa sandbox scripts + thêm CSP)"

  if [[ ! -f "$html" ]]; then
    log_skip "Không tìm thấy: $html"
    return
  fi

  local changed=false

  # Xóa script tags từ các sandbox domain
  if echo "$domains" | tr '|' '\n' | while read -r domain; do
    grep -q "$domain" "$html" && break
  done 2>/dev/null; then
    backup_file "$html"
    node -e "
      const fs = require('fs');
      const domains = '${domains}'.split('|');
      let c = fs.readFileSync('${html}', 'utf8');
      const before = c;
      domains.forEach(domain => {
        const escapedDomain = domain.replace(/\./g, '\\\\.').replace(/\//g, '\\\\/');
        // Script tag bình thường
        c = c.replace(
          new RegExp('<script[^>]*' + escapedDomain + '[^>]*>[\\\\s\\\\S]*?<\\/script>', 'gm'), ''
        );
        // Script self-closing
        c = c.replace(
          new RegExp('<script[^>]*' + escapedDomain + '[^>]*/?>\\\\s*(?:<\\/script>)?', 'gm'), ''
        );
      });
      // Dọn dòng trắng thừa
      c = c.replace(/\\n\\s*\\n\\s*\\n/g, '\\n\\n');
      if (before !== c) {
        fs.writeFileSync('${html}', c);
        console.log('Removed sandbox scripts');
      }
    "
    changed=true
    log_ok "Đã xóa sandbox scripts (domains: ${domains})"
  else
    log_ok "Không có sandbox scripts, bỏ qua"
  fi

  # Thêm Capacitor CSP meta nếu chưa có
  if ! grep -q "capacitor://" "$html"; then
    [[ "$changed" == "false" ]] && backup_file "$html"
    node -e "
      const fs = require('fs');
      let c = fs.readFileSync('${html}', 'utf8');
      const csp = '    <meta http-equiv=\"Content-Security-Policy\" ' +
        'content=\"default-src * data: blob: capacitor: filesystem: ' +
        \"'unsafe-inline' 'unsafe-eval'; \" +
        'img-src * data: blob: capacitor:; media-src * data: blob: capacitor:\">';
      c = c.replace(/(<head[^>]*>)/i, '\$1\n' + csp);
      fs.writeFileSync('${html}', c);
    "
    log_ok "Đã thêm Capacitor CSP meta tag"
  fi
}

# --------------------------------------------------------------------------- #
# Inject eruda (mobile DevTools) vào index.html
# Chỉ chạy khi SHOW_LOG=true. Idempotent (đánh dấu bằng marker comment).
# --------------------------------------------------------------------------- #
inject_debug_console() {
  local html="${INDEX_HTML_PATH:-${PROJECT_ROOT}/index.html}"
  local marker="<!-- mobile-ci:eruda -->"

  log_section "Inject debug console (eruda)"

  if [[ "${SHOW_LOG:-false}" != "true" ]]; then
    # Nếu đã inject trước đó nhưng giờ tắt → xóa
    if [[ -f "$html" ]] && grep -q "mobile-ci:eruda" "$html"; then
      backup_file "$html"
      node -e "
        const fs=require('fs');
        let c=fs.readFileSync('${html}','utf8');
        c=c.replace(/[ \t]*<!-- mobile-ci:eruda -->[\s\S]*?<!-- \/mobile-ci:eruda -->\s*/g,'');
        fs.writeFileSync('${html}',c);
      "
      log_ok "SHOW_LOG=false → đã gỡ eruda khỏi index.html"
    else
      log_skip "SHOW_LOG=false, bỏ qua"
    fi
    return
  fi

  if [[ ! -f "$html" ]]; then
    log_skip "Không tìm thấy: $html"
    return
  fi

  if grep -q "mobile-ci:eruda" "$html"; then
    log_ok "eruda đã được inject"
    return
  fi

  backup_file "$html"
  node -e "
    const fs=require('fs');
    let c=fs.readFileSync('${html}','utf8');
    const snippet = [
      '    <!-- mobile-ci:eruda -->',
      '    <script src=\"https://cdn.jsdelivr.net/npm/eruda\"></script>',
      '    <script>',
      '      (function(){',
      '        if (typeof eruda === \"undefined\") return;',
      '        eruda.init();',
      '        // Patch fetch để log request/response trong Console',
      '        var _f = window.fetch;',
      '        window.fetch = function(){',
      '          var args = arguments;',
      '          var url = typeof args[0] === \"string\" ? args[0] : args[0].url;',
      '          var t0 = Date.now();',
      '          console.log(\"[fetch →]\", url, args[1] || {});',
      '          return _f.apply(this, args).then(function(r){',
      '            console.log(\"[fetch ←]\", r.status, url, (Date.now()-t0)+\"ms\");',
      '            return r;',
      '          }).catch(function(e){',
      '            console.error(\"[fetch ✗]\", url, e && e.message);',
      '            throw e;',
      '          });',
      '        };',
      '      })();',
      '    </script>',
      '    <!-- /mobile-ci:eruda -->',
      ''
    ].join('\n');
    c = c.replace(/(<\/head>)/i, snippet + '\$1');
    fs.writeFileSync('${html}', c);
  "
  log_ok "Đã inject eruda + fetch logger (xuất hiện ở góc app khi mở)"
}

# --------------------------------------------------------------------------- #
# Hàm tổng: chạy tất cả code fixes
# --------------------------------------------------------------------------- #
run_code_fixes() {
  fix_router
  fix_vite_config
  fix_index_html
  inject_debug_console
}
