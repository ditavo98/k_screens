#!/usr/bin/env bash
# lib/01_utils.sh — Tiện ích chung: detect, backup, require, pkg install
#
# Thiết kế cho CI/CD: mỗi hàm tự kiểm tra và cài dependency nếu chưa có.
# Không giả định bất kỳ tool nào đã có sẵn ngoài bash, node, npm.

# Backup file trước khi sửa
backup_file() {
  local file="$1"
  local suffix="${BACKUP_SUFFIX:-.bak}"
  if [[ -f "$file" ]]; then
    cp "$file" "${file}${suffix}"
    log_info "Backed up → $(basename "$file")${suffix}"
  fi
}

# Kiểm tra lệnh tồn tại — nếu không có thì báo lỗi và thoát
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Yêu cầu lệnh '$1' chưa được cài. $2"
    exit 1
  fi
}

# Đảm bảo lệnh tồn tại — nếu chưa có thì tự cài
# Dùng cho các tool biết cách cài tự động
ensure_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    return 0
  fi

  log_warn "'$cmd' chưa có, đang cài..."
  case "$cmd" in
    pnpm)
      npm install -g pnpm
      ;;
    yarn)
      npm install -g yarn
      ;;
    ruby)
      if [[ "$(uname)" == "Darwin" ]]; then
        # macOS thường có Ruby sẵn, nếu không → brew
        if command -v brew &>/dev/null; then
          brew install ruby
        else
          log_error "Ruby chưa được cài. Cài Homebrew rồi: brew install ruby"
          return 1
        fi
      else
        # Linux (Ubuntu — GitHub Actions runner)
        if command -v apt-get &>/dev/null; then
          sudo apt-get update -qq && sudo apt-get install -y -qq ruby-full
        else
          log_error "Ruby chưa được cài. Cài thủ công."
          return 1
        fi
      fi
      ;;
    bundle|bundler)
      gem install bundler --no-document --quiet
      ;;
    python3)
      if [[ "$(uname)" == "Darwin" ]]; then
        log_error "python3 chưa được cài. Cài: xcode-select --install"
        return 1
      else
        if command -v apt-get &>/dev/null; then
          sudo apt-get update -qq && sudo apt-get install -y -qq python3
        else
          log_error "python3 chưa được cài."
          return 1
        fi
      fi
      ;;
    *)
      log_error "'$cmd' chưa có và không biết cách cài tự động."
      return 1
      ;;
  esac

  # Verify sau khi cài
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Cài '$cmd' thất bại."
    return 1
  fi
  log_ok "'$cmd' đã được cài thành công"
}

# Detect package manager từ lock file, rồi đảm bảo nó có sẵn
detect_package_manager() {
  if [[ -f "${PROJECT_ROOT}/pnpm-lock.yaml" ]] || \
     [[ -f "${PROJECT_ROOT}/pnpm-workspace.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
  elif [[ -f "${PROJECT_ROOT}/yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
  else
    PACKAGE_MANAGER="npm"
  fi

  # Đảm bảo package manager binary có sẵn
  if ! command -v "${PACKAGE_MANAGER}" &>/dev/null; then
    log_warn "${PACKAGE_MANAGER} được detect nhưng chưa cài, đang cài..."
    ensure_cmd "${PACKAGE_MANAGER}"
  fi

  log_info "Package manager: ${PACKAGE_MANAGER}"
}

# Cài npm/pnpm/yarn package — tự đảm bảo PM có sẵn
pkg_add() {
  local is_dev="${1:-false}"
  shift
  local pkgs=("$@")

  # Double-check PM có sẵn
  if ! command -v "${PACKAGE_MANAGER:-npm}" &>/dev/null; then
    ensure_cmd "${PACKAGE_MANAGER:-npm}"
  fi

  case "${PACKAGE_MANAGER:-npm}" in
    pnpm) [[ "$is_dev" == "true" ]] && pnpm add -D "${pkgs[@]}" || pnpm add "${pkgs[@]}" ;;
    yarn) [[ "$is_dev" == "true" ]] && yarn add --dev "${pkgs[@]}" || yarn add "${pkgs[@]}" ;;
    *)    [[ "$is_dev" == "true" ]] && npm install --save-dev "${pkgs[@]}" || npm install --save "${pkgs[@]}" ;;
  esac
}

# Kiểm tra package đã cài chưa
pkg_installed() {
  node -e "require('$1')" &>/dev/null 2>&1
}

# Thay thế nội dung file dùng Node.js (safe trên cả macOS lẫn Linux)
node_replace() {
  local file="$1"
  local search="$2"   # regex string
  local replace="$3"
  node -e "
    const fs = require('fs');
    let c = fs.readFileSync('${file}', 'utf8');
    const r = new RegExp(${search}, 'g');
    const u = c.replace(r, \`${replace}\`);
    if (c !== u) { fs.writeFileSync('${file}', u); process.stdout.write('changed'); }
    else { process.stdout.write('unchanged'); }
  "
}

# Kiểm tra và cài Ruby + Bundler cho Fastlane
check_ruby() {
  # Cố gắng cài Ruby nếu chưa có
  if ! ensure_cmd ruby; then
    return 1
  fi

  local ver
  ver=$(ruby -e "puts RUBY_VERSION")
  log_info "Ruby: ${ver}"

  # Cài bundler nếu chưa có
  if ! command -v bundle &>/dev/null; then
    log_info "Cài bundler..."
    gem install bundler --no-document --quiet
    # Nếu gem install vào user dir, thêm vào PATH
    if ! command -v bundle &>/dev/null; then
      local gem_bin
      gem_bin="$(ruby -e 'puts Gem.user_dir')/bin"
      if [[ -d "$gem_bin" ]]; then
        export PATH="${gem_bin}:${PATH}"
        log_info "Thêm ${gem_bin} vào PATH"
      fi
    fi
  fi

  if ! command -v bundle &>/dev/null; then
    log_error "Không tìm thấy bundler sau khi cài"
    return 1
  fi

  log_ok "Ruby ${ver} + Bundler sẵn sàng"
  return 0
}
