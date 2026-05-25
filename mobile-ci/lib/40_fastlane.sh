#!/usr/bin/env bash
# lib/40_fastlane.sh — Tự động setup Fastlane + ASC API action
#
# Biến đầu vào (từ project config):
#   PROJECT_ROOT, APP_ID, APP_NAME, FL_APP_LANGUAGE

# --------------------------------------------------------------------------- #
# Tạo Gemfile
# --------------------------------------------------------------------------- #
_fl_create_gemfile() {
  local gemfile="${PROJECT_ROOT}/Gemfile"

  if [[ -f "$gemfile" ]] && grep -q 'fastlane' "$gemfile"; then
    log_ok "Gemfile đã chứa fastlane"
    if ! grep -q 'gem "json"' "$gemfile"; then
      log_info "Auto-patch: Thêm gem json >= 2.7.2 vào Gemfile cũ và xoá lockfile"
      echo 'gem "json", ">= 2.7.2"' >> "$gemfile"
      rm -f "${PROJECT_ROOT}/Gemfile.lock"
    fi
    return
  fi

  [[ -f "$gemfile" ]] && backup_file "$gemfile"
  log_info "Tạo Gemfile..."

  cat > "$gemfile" << 'EOF'
source "https://rubygems.org"

gem "fastlane", ">= 2.220.0"
gem "jwt",      ">= 2.7.0"
gem "json",     "~> 2.7.2"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF
  log_ok "Gemfile đã được tạo"
}

# --------------------------------------------------------------------------- #
# Tạo fastlane/Appfile
# --------------------------------------------------------------------------- #
_fl_create_appfile() {
  local appfile="${PROJECT_ROOT}/fastlane/Appfile"
  mkdir -p "${PROJECT_ROOT}/fastlane"

  [[ -f "$appfile" ]] && { log_ok "Appfile đã tồn tại"; return; }

  log_info "Tạo fastlane/Appfile..."
  cat > "$appfile" << EOF
# Appfile — ${APP_NAME}
# Đọc từ biến môi trường CI/CD
app_identifier(ENV["APP_BUNDLE_ID"] || "${APP_ID}")
team_id(ENV["APPLE_TEAM_ID"] || "")
itc_team_id(ENV["ITC_TEAM_ID"] || ENV["APPLE_TEAM_ID"] || "")
# apple_id — bỏ dòng này để tránh Spaceship auth khi dùng ASC API Key
EOF
  log_ok "fastlane/Appfile đã được tạo"
}

_fl_patch_appfile() {
  local appfile="${PROJECT_ROOT}/fastlane/Appfile"
  [[ ! -f "$appfile" ]] && return

  if grep -q '^apple_id' "$appfile"; then
    log_info "Auto-patch Appfile: Comment out apple_id để tránh Spaceship auth"
    sed -i.bak 's/^apple_id/# apple_id/' "$appfile"
    rm -f "${appfile}.bak"
    log_ok "Appfile đã được patch"
  fi
}

# --------------------------------------------------------------------------- #
# Tạo fastlane/actions/create_bundle_id.rb
# Custom action gọi ASC REST API để tạo Bundle ID
# --------------------------------------------------------------------------- #
_fl_create_asc_action() {
  local dir="${PROJECT_ROOT}/fastlane/actions"
  mkdir -p "$dir"

  local file="${dir}/create_bundle_id.rb"
  [[ -f "$file" ]] && { log_ok "create_bundle_id.rb đã tồn tại"; return; }

  log_info "Tạo fastlane/actions/create_bundle_id.rb..."
  cat > "$file" << 'RBEOF'
# fastlane/actions/create_bundle_id.rb
#
# Custom Fastlane action: Tạo Bundle ID trên Apple Developer Portal
# qua App Store Connect REST API v1
#
# Xác thực bằng JWT ES256 — không cần Apple ID / password.
# Docs: https://developer.apple.com/documentation/appstoreconnectapi
#
require "net/http"
require "json"
require "openssl"
require "base64"
require "time"

module Fastlane
  module Actions
    class CreateBundleIdAction < Action

      # ── Tạo JWT token (ES256) ──────────────────────────────────────────────
      def self.generate_jwt(key_id:, issuer_id:, key_content:)
        header  = { alg: "ES256", kid: key_id, typ: "JWT" }
        now     = Time.now.to_i
        payload = {
          iss: issuer_id,
          iat: now,
          exp: now + 1200,  # tối đa 20 phút
          aud: "appstoreconnect-v1",
        }

        private_key = OpenSSL::PKey::EC.new(key_content)
        b64         = ->(d) { Base64.urlsafe_encode64(d, padding: false) }
        input       = "#{b64.(header.to_json)}.#{b64.(payload.to_json)}"

        # Sign → DER/ASN.1 → raw R||S (64 bytes)
        digest   = OpenSSL::Digest::SHA256.new
        asn1_sig = private_key.sign(digest, input)
        asn1     = OpenSSL::ASN1.decode(asn1_sig)
        r        = asn1.value[0].value.to_s(2).rjust(32, "\x00")[-32..]
        s        = asn1.value[1].value.to_s(2).rjust(32, "\x00")[-32..]

        "#{input}.#{b64.(r + s)}"
      end

      # ── POST /v1/bundleIds ─────────────────────────────────────────────────
      def self.run(params)
        token = generate_jwt(
          key_id:      params[:api_key_id],
          issuer_id:   params[:api_issuer_id],
          key_content: params[:api_key_content],
        )

        body = {
          data: {
            type:       "bundleIds",
            attributes: {
              identifier: params[:bundle_id],
              name:       params[:name],
              platform:   params[:platform] || "IOS",
            },
          },
        }.to_json

        resp = call_api("POST", "https://api.appstoreconnect.apple.com/v1/bundleIds", token, body)
        data = JSON.parse(resp.body)

        case resp.code.to_i
        when 201
          attrs = data.dig("data", "attributes") || {}
          UI.success("[ASC] Bundle ID tạo thành công: #{attrs['identifier']}")
          {
            success:    true,
            id:         data.dig("data", "id"),
            identifier: attrs["identifier"],
            name:       attrs["name"],
            platform:   attrs["platform"],
          }
        when 409
          # ENTITY_ALREADY_EXISTS — không phải lỗi
          UI.important("[ASC] Bundle ID đã tồn tại, đang lấy thông tin...")
          get_existing_bundle_id(token, params[:bundle_id])
        else
          msg = data.dig("errors", 0, "detail") ||
                data.dig("errors", 0, "title")  ||
                resp.body
          UI.error("[ASC] Lỗi #{resp.code}: #{msg}")
          { success: false, error: msg }
        end
      rescue => e
        UI.error("[ASC] Exception: #{e.message}")
        { success: false, error: e.message }
      end

      # ── GET /v1/bundleIds?filter[identifier]=... ───────────────────────────
      def self.get_existing_bundle_id(token, identifier)
        url  = "https://api.appstoreconnect.apple.com/v1/bundleIds?filter[identifier]=#{URI.encode_www_form_component(identifier)}"
        resp = call_api("GET", url, token)
        data = JSON.parse(resp.body)
        rec  = data.dig("data", 0)
        return { success: false, error: "Bundle ID not found after 409" } unless rec

        attrs = rec["attributes"] || {}
        UI.success("[ASC] Bundle ID tìm thấy: #{attrs['identifier']}")
        {
          success:    true,
          id:         rec["id"],
          identifier: attrs["identifier"],
          name:       attrs["name"],
          platform:   attrs["platform"],
        }
      end

      # ── HTTP helper ────────────────────────────────────────────────────────
      def self.call_api(method, url, token, body = nil)
        uri  = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.read_timeout = 30

        req = Net::HTTP.const_get(method.capitalize).new(uri)
        req["Authorization"] = "Bearer #{token}"
        req["Content-Type"]  = "application/json"
        req.body = body if body
        http.request(req)
      end

      def self.description
        "Tạo Bundle ID trên Apple Developer Portal qua App Store Connect REST API"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_key_id,      description: "Key ID từ ASC",           type: String),
          FastlaneCore::ConfigItem.new(key: :api_issuer_id,   description: "Issuer ID từ ASC",         type: String),
          FastlaneCore::ConfigItem.new(key: :api_key_content, description: "Nội dung file .p8",        type: String, sensitive: true),
          FastlaneCore::ConfigItem.new(key: :bundle_id,       description: "Bundle Identifier",        type: String),
          FastlaneCore::ConfigItem.new(key: :name,            description: "Tên Bundle ID",            type: String),
          FastlaneCore::ConfigItem.new(key: :platform,        description: "IOS hoặc MAC_OS",          type: String, default_value: "IOS"),
        ]
      end

      def self.return_value
        "Hash: { success, id, identifier, name, platform } hoặc { success: false, error }"
      end

      def self.is_supported?(platform) = platform == :ios
    end
  end
end
RBEOF
  log_ok "fastlane/actions/create_bundle_id.rb đã được tạo"
}

# --------------------------------------------------------------------------- #
# Tạo fastlane/Fastfile — render từ biến PROJECT_ROOT, APP_ID, APP_NAME, v.v.
# --------------------------------------------------------------------------- #
_fl_create_fastfile() {
  local fastfile="${PROJECT_ROOT}/fastlane/Fastfile"
  [[ -f "$fastfile" ]] && { 
    log_ok "Fastfile đã tồn tại"
    # Auto-patch Fastfile cũ
    if grep -q 'lane :create_bundle_id' "$fastfile"; then
      log_info "Auto-patch: Đổi tên lane create_bundle_id -> register_bundle_id trong Fastfile cũ"
      sed -i.bak 's/lane :create_bundle_id/lane :register_bundle_id/g' "$fastfile"
      sed -i.bak 's/create_bundle_id(/register_bundle_id(/g' "$fastfile"
      sed -i.bak 's/create_bundle_id unless/register_bundle_id unless/g' "$fastfile"
      rm -f "${fastfile}.bak"
    fi
    if grep -q 'produce(' "$fastfile" && grep -q 'username:' "$fastfile"; then
      log_info "Auto-patch: Xóa username khỏi produce để ép dùng API Key"
      sed -i.bak '/username:/d' "$fastfile"
      rm -f "${fastfile}.bak"
    fi
    if grep -q 'produce(' "$fastfile" && ! grep -q 'skip_devcenter: true' "$fastfile"; then
      log_info "Auto-patch: Thêm skip_devcenter: true vào produce"
      sed -i.bak 's/produce(/produce(\n    skip_devcenter: true,/g' "$fastfile"
      rm -f "${fastfile}.bak"
    fi
    if grep -q 'produce(' "$fastfile" && ! grep -q 'ENV\["APPLE_ID"\] = nil' "$fastfile"; then
      log_info "Auto-patch: Xóa sạch ENV APPLE_ID trước khi gọi produce"
      sed -i.bak '/produce(/i\
    ENV["APPLE_ID"] = nil\
    ENV["FASTLANE_USER"] = nil\
' "$fastfile"
      rm -f "${fastfile}.bak"
    fi
    return
  }

  log_info "Tạo fastlane/Fastfile..."

  # Dùng process substitution để expand biến shell vào nội dung Fastfile
  cat > "$fastfile" << FFEOF
# =============================================================================
# Fastfile — ${APP_NAME}
# Auto-generated by mobile-ci service
#
# Lanes:
#   bundle exec fastlane create_bundle_id   → Tạo Bundle ID qua ASC API
#   bundle exec fastlane create_app         → Tạo app trên App Store Connect
#   bundle exec fastlane setup_signing      → Tạo cert + provisioning (match)
#   bundle exec fastlane build_ios          → Build IPA (gym)
#   bundle exec fastlane release_testflight → Upload TestFlight (pilot)
#   bundle exec fastlane full_setup         → Toàn bộ flow lần đầu
#   bundle exec fastlane ci_pipeline        → CI/CD tự động
#
# Biến môi trường bắt buộc (xem .env của Runner / .env.runner.example):
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_CONTENT
#   APP_BUNDLE_ID, APP_NAME, APPLE_ID, APPLE_TEAM_ID
# =============================================================================

require "json"
require "base64"
require "time"

before_all do
  setup_ci if ENV["CI"]
  # Global register ASC API key for all actions (including Xcode automatic signing)
  app_store_connect_api_key(**asc_api_key)
end

# Load App Store Connect API Key ─────────────────────────────────────────────────
def asc_api_key
  content = ENV["ASC_PRIVATE_KEY_CONTENT"]
  # Nếu base64-encoded (thường dùng trong CI/CD secrets)
  content = Base64.decode64(content) if content && !content.include?("-----BEGIN")
  if content.nil? || content.strip.empty?
    path = ENV["ASC_PRIVATE_KEY_PATH"] || "fastlane/asc_private_key.p8"
    UI.user_error!("ASC private key không tìm thấy: #{path}") unless File.exist?(path)
    content = File.read(path)
  end
  {
    key_id:               ENV["ASC_KEY_ID"]    || UI.user_error!("Thiếu ASC_KEY_ID"),
    issuer_id:            ENV["ASC_ISSUER_ID"] || UI.user_error!("Thiếu ASC_ISSUER_ID"),
    key_content:          content,
    is_key_content_base64: false,
    duration:             1200,
    in_house:             false,
  }
end

# ── LANE: register_bundle_id ───────────────────────────────────────────────────
lane :register_bundle_id do |opts|
  UI.header("🆔 Tạo Bundle ID qua ASC API")
  bundle_id = opts[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  name      = opts[:name]      || ENV["APP_NAME"]      || "${APP_NAME}"
  key       = asc_api_key

  result = Actions::CreateBundleIdAction.run(
    api_key_id:      key[:key_id],
    api_issuer_id:   key[:issuer_id],
    api_key_content: key[:key_content],
    bundle_id:       bundle_id,
    name:            name,
    platform:        opts[:platform] || "IOS",
  )

  if result[:success]
    UI.success("✅ Bundle ID: #{result[:identifier]} (id=#{result[:id]})")
    File.write(File.join(__dir__, "bundle_id_result.json"), JSON.pretty_generate(result))
  else
    unless ["ENTITY_ALREADY_EXISTS", "already exists"].any? { |s| result[:error].to_s.include?(s) }
      UI.user_error!(result[:error])
    end
    UI.important("Bundle ID đã tồn tại, tiếp tục...")
  end
end

# ── LANE: create_app ─────────────────────────────────────────────────────────
lane :create_app do |opts|
  UI.header("📱 Tạo App trên App Store Connect")
  bundle_id = opts[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  app_name  = opts[:app_name]  || ENV["APP_NAME"]      || "${APP_NAME}"
  sku       = opts[:sku]       || ENV["APP_SKU"]        || bundle_id.gsub(".", "-")
  language  = opts[:language]  || ENV["APP_LANGUAGE"]   || "${FL_APP_LANGUAGE:-ko}"

  register_bundle_id(bundle_id: bundle_id, name: app_name)

  # Dùng Spaceship 2.0 qua ASC API — không cần produce
  key = asc_api_key
  api_key = app_store_connect_api_key(
    key_id:                key[:key_id],
    issuer_id:             key[:issuer_id],
    key_content:           key[:key_content],
    is_key_content_base64: false,
    duration:              1200,
    in_house:              false,
  )

  begin
    Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.from(hash: api_key)
    app = Spaceship::ConnectAPI::App.find(bundle_id)
    if app
      UI.important("App đã tồn tại trên ASC: #{bundle_id}")
    else
      app = Spaceship::ConnectAPI::App.create(
        name:               app_name,
        version_string:     "1.0",
        sku:                sku,
        primary_locale:     language,
        bundle_id:          bundle_id,
        platforms:          ["IOS"],
      )
      UI.success("✅ App tạo thành công: #{app_name} (#{bundle_id})")
    end
  rescue => e
    UI.user_error!("Lỗi tạo app: #{e.message}")
  end
end

# ── LANE: setup_signing ──────────────────────────────────────────────────────
lane :setup_signing do |opts|
  UI.header("🔑 Setup Code Signing (Match)")

  git_url = ENV["MATCH_GIT_URL"]
  if git_url.nil? || git_url.empty?
    UI.user_error!("Thiếu MATCH_GIT_URL! Vui lòng cấu hình biến môi trường hoặc GitHub Secret MATCH_GIT_URL.")
  end

  # Match đọc MATCH_PASSWORD từ env tự động
  key = asc_api_key
  api_key_result = app_store_connect_api_key(
    key_id:         key[:key_id],
    issuer_id:      key[:issuer_id],
    key_content:    key[:key_content],
    is_key_content_base64: false,
    duration:       1200,
    in_house:       false,
  )

  match(
    type:                  opts[:type] || ENV["MATCH_TYPE"] || "appstore",
    app_identifier:        opts[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}",
    git_url:               git_url,
    git_branch:            ENV["MATCH_GIT_BRANCH"] || "main",
    readonly:              ENV["CI"] ? true : false,
    clone_branch_directly: true,
    force_for_new_devices: !ENV["CI"],
    api_key:               api_key_result,
  )
  UI.success("✅ Code signing xong (type=#{opts[:type] || 'appstore'})")
end

# ── LANE: build_ios ──────────────────────────────────────────────────────────
lane :build_ios do |opts|
  UI.header("🏗️  Build iOS IPA")
  bundle_id = opts[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"

  if ENV["MATCH_GIT_URL"].nil? || ENV["MATCH_GIT_URL"].empty?
    UI.important("⚠️ Bỏ qua setup_signing vì MATCH_GIT_URL trống. Sẽ cố gắng build Xcode mà không dùng Match...")
  else
    setup_signing(bundle_id: bundle_id, type: "appstore") unless opts[:skip_signing]
  end

  export_opts = {}
  if ENV["MATCH_GIT_URL"] && !ENV["MATCH_GIT_URL"].empty?
    export_opts = { provisioningProfiles: { bundle_id => "match AppStore #{bundle_id}" } }
  end

  xc_args = []
  if ENV["APPLE_TEAM_ID"] && !ENV["APPLE_TEAM_ID"].empty?
    xc_args << "DEVELOPMENT_TEAM=#{ENV["APPLE_TEAM_ID"]}"
  end

  if ENV["MATCH_GIT_URL"].nil? || ENV["MATCH_GIT_URL"].empty?
    xc_args << "-allowProvisioningUpdates"
  end

  xc_args_str = xc_args.join(" ")
  xc_args_str = nil if xc_args_str.empty?

  workspace_path = "ios/App/App.xcworkspace"
  project_path = "ios/App/App.xcodeproj"
  
  gym_options = {
    scheme:            opts[:scheme] || ENV["IOS_SCHEME"] || "App",
    configuration:     opts[:config] || ENV["BUILD_CONFIG"] || "Release",
    export_method:     "app-store",
    output_directory:  "build",
    output_name:       "App.ipa",
    clean:             true,
    include_symbols:   true,
    include_bitcode:   false,
    xcargs:            xc_args_str,
    export_options:    export_opts,
  }

  if Dir.exist?(workspace_path)
    gym_options[:workspace] = workspace_path
  else
    gym_options[:project] = project_path
  end

  gym(**gym_options)
  UI.success("✅ Build xong: build/App.ipa")
end

# ── LANE: release_testflight ─────────────────────────────────────────────────
lane :release_testflight do |opts|
  UI.header("🚀 Upload lên TestFlight")
  pilot(
    api_key:                           asc_api_key,
    ipa:                               opts[:ipa_path] || "build/App.ipa",
    skip_waiting_for_build_processing: true,
    distribute_external:               false,
    notify_external_testers:           false,
    changelog:                         opts[:changelog] || ENV["RELEASE_NOTES"] || "Build mới",
    beta_app_description:              "${APP_NAME}",
    demo_account_required:             false,
  )
  UI.success("✅ Upload TestFlight thành công!")
end

# ── LANE: full_setup ─────────────────────────────────────────────────────────
lane :full_setup do |opts|
  UI.header("🎬 Full Setup — ${APP_NAME}")
  bundle_id = opts[:bundle_id] || ENV["APP_BUNDLE_ID"] || "${APP_ID}"
  app_name  = opts[:app_name]  || ENV["APP_NAME"]      || "${APP_NAME}"

  create_bundle_id(bundle_id: bundle_id, name: app_name)
  create_app(bundle_id: bundle_id, app_name: app_name)

  if ENV["MATCH_GIT_URL"] && !ENV["MATCH_GIT_URL"].empty?
    setup_signing(bundle_id: bundle_id, type: "development")
    setup_signing(bundle_id: bundle_id, type: "appstore")
  else
    UI.important("Bỏ qua setup_signing (MATCH_GIT_URL chưa có)")
  end
  UI.success("🎉 Full setup hoàn tất!")
end

# ── LANE: ci_pipeline ────────────────────────────────────────────────────────
lane :ci_pipeline do
  UI.header("⚙️  CI Pipeline — ${APP_NAME}")
  register_bundle_id unless ENV["SKIP_ASC_SETUP"] == "true"
  create_app         unless ENV["SKIP_ASC_SETUP"] == "true"
  build_ios          unless ENV["SKIP_BUILD"]     == "true"
  release_testflight(
    changelog: ENV["RELEASE_NOTES"] || "CI build - \#{Time.now.strftime('%Y-%m-%d %H:%M')}",
  ) unless ENV["SKIP_UPLOAD"] == "true"
end

error do |lane, exception|
  UI.error("❌ Lane '#{lane}' lỗi: #{exception.message}")
  if ENV["SLACK_WEBHOOK_URL"] && !ENV["SLACK_WEBHOOK_URL"].empty?
    slack(
      message: "❌ ${APP_NAME} build lỗi: #{exception.message}",
      slack_url: ENV["SLACK_WEBHOOK_URL"],
      success: false,
      default_payloads: [:lane, :git_branch, :git_author],
    )
  end
end
FFEOF
  log_ok "fastlane/Fastfile đã được tạo"
}

# --------------------------------------------------------------------------- #
# Chạy bundle install
# --------------------------------------------------------------------------- #
_fl_bundle_install() {
  log_section "Bundle Install"
  cd "$PROJECT_ROOT"

  # Đảm bảo bundler có sẵn
  ensure_cmd bundle || { log_warn "Bỏ qua bundle install (bundler không có)"; return; }

  if bundle check &>/dev/null 2>&1; then
    log_ok "Gems đã đầy đủ"
    return
  fi

  log_info "Chạy bundle install..."
  bundle install --jobs=4 --retry=3
  log_ok "bundle install hoàn tất"
}

# --------------------------------------------------------------------------- #
# Hàm tổng: setup_fastlane
# Chỉ chạy khi có ít nhất 1 platform được add
# --------------------------------------------------------------------------- #
run_fastlane_setup() {
  if [[ "${SKIP_FASTLANE:-false}" == "true" ]]; then
    log_skip "SKIP_FASTLANE=true → Bỏ qua Fastlane"
    return
  fi

  # Kiểm tra có platform nào chưa
  if [[ ! -d "${PROJECT_ROOT}/ios" ]] && [[ ! -d "${PROJECT_ROOT}/android" ]]; then
    log_skip "Chưa có platform nào (ios/ hoặc android/) → Bỏ qua Fastlane"
    log_info "Đặt PLATFORMS=\"ios\" hoặc \"android\" để kích hoạt"
    return
  fi

  log_section "Fastlane Setup"

  if ! check_ruby; then
    log_warn "Bỏ qua Fastlane (Ruby chưa được cài)"
    return
  fi

  _fl_create_gemfile
  _fl_patch_appfile
  _fl_create_appfile
  _fl_create_asc_action
  _fl_create_fastfile
  _fl_bundle_install

  log_ok "Fastlane setup hoàn tất!"
}
