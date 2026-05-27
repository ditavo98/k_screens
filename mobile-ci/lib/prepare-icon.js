#!/usr/bin/env node
/**
 * prepare-icon.js — Chuẩn bị icon nguồn cho @capacitor/assets generate.
 *
 * Logic:
 *   1. Xác định icon source:
 *      - APP_ICON env (URL http(s) hoặc local path) nếu được set
 *      - Hoặc parse <link rel="icon"> trong INDEX_HTML (mặc định ${PROJECT_ROOT}/index.html)
 *   2. Nếu là URL → download; nếu là local path → đọc file
 *   3. Ghi ra ${PROJECT_ROOT}/resources/icon.png
 *
 * Env vào:
 *   PROJECT_ROOT     (bắt buộc) — gốc project Capacitor
 *   APP_ICON         (tuỳ chọn) — URL hoặc đường dẫn (tuyệt đối / tương đối CONFIG_DIR)
 *   INDEX_HTML_PATH  (tuỳ chọn) — đường dẫn index.html
 *   CONFIG_DIR       (tuỳ chọn) — thư mục mobile.config.sh (để resolve APP_ICON tương đối)
 *
 * Thoát: 0 nếu ghi được resources/icon.png; non-zero nếu lỗi/không có icon.
 */

const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");

const PROJECT_ROOT = process.env.PROJECT_ROOT;
if (!PROJECT_ROOT) {
  console.error("[prepare-icon] PROJECT_ROOT chưa được set");
  process.exit(2);
}

const APP_ICON = (process.env.APP_ICON || "").trim();
const INDEX_HTML =
  (process.env.INDEX_HTML_PATH || "").trim() ||
  path.join(PROJECT_ROOT, "index.html");
const CONFIG_DIR = (process.env.CONFIG_DIR || "").trim() || PROJECT_ROOT;

const DEST = path.join(PROJECT_ROOT, "resources", "icon.png");

function isUrl(s) {
  return /^https?:\/\//i.test(s);
}

function extractIconHrefFromHtml(htmlPath) {
  if (!fs.existsSync(htmlPath)) return null;
  const html = fs.readFileSync(htmlPath, "utf8");
  const linkTagRe = /<link\b[^>]*>/gi;
  const priorities = ["icon", "shortcut icon", "apple-touch-icon"];
  const found = {};
  let m;
  while ((m = linkTagRe.exec(html)) !== null) {
    const tag = m[0];
    const attrs = {};
    const attrRe = /\b([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
    let a;
    while ((a = attrRe.exec(tag)) !== null) {
      attrs[a[1].toLowerCase()] = a[2] ?? a[3] ?? a[4] ?? "";
    }
    const rel = (attrs.rel || "").toLowerCase();
    const href = attrs.href || "";
    if (rel && href && priorities.includes(rel) && !found[rel]) {
      found[rel] = href;
    }
  }
  for (const rel of priorities) {
    if (found[rel]) return found[rel];
  }
  return null;
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith("https:") ? https : http;
    const req = client.get(url, (res) => {
      if (
        res.statusCode &&
        res.statusCode >= 300 &&
        res.statusCode < 400 &&
        res.headers.location
      ) {
        res.resume();
        const next = new URL(res.headers.location, url).toString();
        download(next, dest).then(resolve, reject);
        return;
      }
      if (res.statusCode !== 200) {
        res.resume();
        reject(new Error(`HTTP ${res.statusCode} khi tải ${url}`));
        return;
      }
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      const out = fs.createWriteStream(dest);
      res.pipe(out);
      out.on("finish", () => out.close(() => resolve(dest)));
      out.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(30000, () => req.destroy(new Error("Timeout tải icon")));
  });
}

function resolveLocalPath(raw) {
  if (path.isAbsolute(raw)) return raw;
  return path.resolve(CONFIG_DIR, raw);
}

async function main() {
  let source = APP_ICON;
  let origin = "APP_ICON";
  if (!source) {
    source = extractIconHrefFromHtml(INDEX_HTML);
    origin = `index.html (${path.relative(PROJECT_ROOT, INDEX_HTML) || INDEX_HTML})`;
  }
  if (!source) {
    console.error(
      `[prepare-icon] Không tìm thấy icon: APP_ICON trống và không có <link rel="icon"> trong ${INDEX_HTML}`
    );
    process.exit(3);
  }

  console.log(`[prepare-icon] Source (${origin}): ${source}`);

  fs.mkdirSync(path.dirname(DEST), { recursive: true });

  if (isUrl(source)) {
    await download(source, DEST);
  } else {
    const src = resolveLocalPath(source);
    if (!fs.existsSync(src)) {
      throw new Error(`Không tìm thấy file icon: ${src}`);
    }
    fs.copyFileSync(src, DEST);
  }

  const size = fs.statSync(DEST).size;
  if (size === 0) {
    throw new Error(`File icon ghi ra rỗng: ${DEST}`);
  }
  console.log(`[prepare-icon] Đã ghi ${DEST} (${size} bytes)`);
}

main().catch((err) => {
  console.error(`[prepare-icon] Lỗi: ${err.message}`);
  process.exit(1);
});
