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

// File signatures
const PNG_SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const ICO_HEADER = Buffer.from([0x00, 0x00, 0x01, 0x00]); // reserved=0, type=1=ICO

function isPng(buf) {
  return buf.length >= 8 && buf.subarray(0, 8).equals(PNG_SIG);
}

function isIco(buf) {
  return buf.length >= 4 && buf.subarray(0, 4).equals(ICO_HEADER);
}

/**
 * Extract PNG có kích thước lớn nhất từ ICO file (Windows icon container).
 * Trả về Buffer chứa PNG, hoặc null nếu ICO không chứa PNG embedded
 * (mà chứa BMP/DIB — không hỗ trợ convert ở đây).
 *
 * ICO layout:
 *   - Header (6 bytes): reserved (2), type (2)=1, count (2)
 *   - n × IconDirEntry (16 bytes mỗi cái):
 *       width(1), height(1), colorCount(1), reserved(1),
 *       planes(2), bitCount(2), bytesInRes(4), imageOffset(4)
 *   - Image data tại các offset (PNG hoặc BMP/DIB)
 */
function extractLargestPngFromIco(buffer) {
  if (!isIco(buffer)) return null;
  const count = buffer.readUInt16LE(4);
  let best = null;
  for (let i = 0; i < count; i++) {
    const off = 6 + i * 16;
    if (off + 16 > buffer.length) break;
    let w = buffer.readUInt8(off);
    let h = buffer.readUInt8(off + 1);
    if (w === 0) w = 256;
    if (h === 0) h = 256;
    const size = buffer.readUInt32LE(off + 8);
    const imgOffset = buffer.readUInt32LE(off + 12);
    if (!best || w * h > best.w * best.h) {
      best = { w, h, size, imgOffset };
    }
  }
  if (!best) return null;
  const data = buffer.subarray(best.imgOffset, best.imgOffset + best.size);
  if (isPng(data)) return data;
  return null; // BMP/DIB embedded — không convert được
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

  // Validate format. URL favicon nhiều khi là ICO multi-resolution (sharp
  // không đọc được) → extract PNG lớn nhất bên trong.
  const buf = fs.readFileSync(DEST);
  if (isPng(buf)) {
    console.log(`[prepare-icon] Đã ghi ${DEST} (${size} bytes, PNG)`);
  } else if (isIco(buf)) {
    console.log(`[prepare-icon] File là ICO — extract PNG lớn nhất bên trong`);
    const png = extractLargestPngFromIco(buf);
    if (!png) {
      throw new Error(
        `Source là ICO nhưng chỉ chứa BMP embedded (không convert được). ` +
          `Hãy cung cấp APP_ICON là file PNG/JPEG riêng (>= 1024x1024).`
      );
    }
    fs.writeFileSync(DEST, png);
    console.log(
      `[prepare-icon] Đã extract PNG (${png.length} bytes) → ${DEST}`
    );
  } else {
    // Sharp hỗ trợ PNG/JPEG/WebP/AVIF/TIFF/GIF — không validate hết,
    // nhưng cảnh báo nếu không phải PNG để dễ debug.
    const head = buf.subarray(0, 4).toString("hex");
    console.warn(
      `[prepare-icon] CẢNH BÁO: file không bắt đầu bằng signature PNG/ICO ` +
        `(magic=${head}). Có thể sharp/capacitor-assets sẽ không đọc được.`
    );
  }
}

main().catch((err) => {
  console.error(`[prepare-icon] Lỗi: ${err.message}`);
  process.exit(1);
});
