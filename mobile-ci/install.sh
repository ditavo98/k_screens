#!/usr/bin/env bash
# install.sh — Cài mobile-ci vào PATH (~/.local/bin)
#
# Cách dùng:
#   bash mobile-ci/install.sh
#
# Sau khi cài:
#   mobile-ci help
#   mobile-ci init   (trong thư mục của project)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
TARGET="${INSTALL_DIR}/mobile-ci"

echo "🚀 Installing mobile-ci service..."

# Tạo thư mục nếu chưa có
mkdir -p "$INSTALL_DIR"

# Tạo symlink (hoặc wrapper script)
if [[ -L "$TARGET" ]] || [[ -f "$TARGET" ]]; then
  echo "⚠  Đã tồn tại: $TARGET — ghi đè..."
  rm -f "$TARGET"
fi

# Tạo wrapper script (dùng script thay vì symlink để dễ debug)
cat > "$TARGET" << EOF
#!/usr/bin/env bash
# mobile-ci wrapper — installed by mobile-ci/install.sh
exec "${SCRIPT_DIR}/bin/mobile-ci" "\$@"
EOF
chmod +x "$TARGET"

# Thêm ~/.local/bin vào PATH nếu chưa có
add_to_path() {
  # GitHub Actions: dùng $GITHUB_PATH để PATH persist giữa các steps
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${INSTALL_DIR}" >> "$GITHUB_PATH"
    echo "✅ Đã thêm ${INSTALL_DIR} vào GITHUB_PATH"
    return
  fi

  # Local: KHÔNG tự sửa .zshrc hay .bashrc
  # In hướng dẫn để người dùng tự thêm nếu muốn
  if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
    echo ""
    echo "💡 Để dùng lệnh 'mobile-ci' trong terminal hiện tại:"
    echo "   export PATH=\"\${HOME}/.local/bin:\$PATH\""
    echo ""
    echo "   Nếu muốn thêm vĩnh viễn, tự thêm dòng trên vào ~/.zshrc"
  fi
}

add_to_path

# Cấp quyền thực thi cho tất cả scripts
chmod +x "${SCRIPT_DIR}/bin/mobile-ci"
chmod +x "${SCRIPT_DIR}/lib/"*.sh

echo ""
echo "✅ mobile-ci đã được cài tại: ${TARGET}"
echo ""
echo "📖 Cách dùng:"
echo "   cd /path/to/your-project"
echo "   mobile-ci init          # tạo mobile.config.sh"
echo "   mobile-ci setup         # setup đầy đủ"
echo "   mobile-ci help          # xem tất cả commands"
echo ""
echo "⚡ Chạy ngay (không cần mở terminal mới):"
echo "   export PATH=\"\${HOME}/.local/bin:\$PATH\""
echo ""
