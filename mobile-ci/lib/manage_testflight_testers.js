#!/usr/bin/env node
import fs from 'fs';
import jwt from 'jsonwebtoken';
import axios from 'axios';

const [,, ACTION, EMAILS_ARG] = process.argv;

if (!ACTION || !['add', 'remove'].includes(ACTION)) {
  console.log('Usage:');
  console.log('  node manage_testflight_testers.js <add|remove> [a@test.com,b@test.com]');
  console.log('');
  console.log('Nếu không truyền danh sách email qua CLI, script sẽ đọc từ biến môi trường');
  console.log('TESTFLIGHT_TESTERS (thường được khai báo trong mobile.config.sh).');
  console.log('');
  console.log('Ví dụ:');
  console.log('  node manage_testflight_testers.js add a@test.com,b@test.com');
  console.log('  source mobile.config.sh && node manage_testflight_testers.js add');
  process.exit(1);
}

// Ưu tiên CLI arg, fallback về env var TESTFLIGHT_TESTERS (từ mobile.config.sh)
const EMAILS_SOURCE = EMAILS_ARG || process.env.TESTFLIGHT_TESTERS || '';

const EMAILS = EMAILS_SOURCE
  .split(/[,\n\r\s]+/)
  .map(e => e.trim())
  .filter(Boolean);

if (EMAILS.length === 0) {
  console.error('❌ Không có email nào được cung cấp.');
  console.error('   → Truyền qua CLI: node manage_testflight_testers.js add a@test.com,b@test.com');
  console.error('   → Hoặc set TESTFLIGHT_TESTERS trong mobile.config.sh');
  process.exit(1);
}

console.log(`📧 ${EMAILS.length} email(s) ${ACTION === 'add' ? 'để thêm' : 'để xoá'}: ${EMAILS.join(', ')}`);

// ========================
// APPLE CONFIG
// ========================
// Hỗ trợ cả 2 naming convention:
//   - APPLE_KEY_ID / APPLE_ISSUER_ID / APPLE_P8_PATH (cách cũ)
//   - ASC_KEY_ID   / ASC_ISSUER_ID   / ASC_PRIVATE_KEY_PATH / ASC_PRIVATE_KEY_CONTENT (Fastlane)
const KEY_ID      = process.env.APPLE_KEY_ID    || process.env.ASC_KEY_ID;
const ISSUER_ID   = process.env.APPLE_ISSUER_ID || process.env.ASC_ISSUER_ID;
const P8_PATH     = process.env.APPLE_P8_PATH   || process.env.ASC_PRIVATE_KEY_PATH;
const P8_CONTENT  = process.env.APPLE_P8_CONTENT || process.env.ASC_PRIVATE_KEY_CONTENT;
// IOS_APP_ID = ASC numeric app ID. Nếu thiếu, sẽ tự lookup qua BUNDLE_ID.
const BUNDLE_ID   = process.env.APP_BUNDLE_ID || process.env.BUNDLE_ID || process.env.APP_ID;
let   IOS_APP_ID  = process.env.IOS_APP_ID;
const GROUP_NAME  = 'External Testers';

for (const [k, v] of Object.entries({ KEY_ID, ISSUER_ID })) {
  if (!v) {
    console.error(`❌ Thiếu env var: ${k} (hoặc alias tương ứng).`);
    process.exit(1);
  }
}
if (!IOS_APP_ID && !BUNDLE_ID) {
  console.error('❌ Cần một trong: IOS_APP_ID (ASC numeric ID) hoặc APP_BUNDLE_ID/BUNDLE_ID/APP_ID (bundle id) để lookup.');
  process.exit(1);
}
if (!P8_CONTENT && !P8_PATH) {
  console.error('❌ Cần một trong: APPLE_P8_PATH / ASC_PRIVATE_KEY_PATH / ASC_PRIVATE_KEY_CONTENT.');
  process.exit(1);
}

// ========================
// HELPERS
// ========================
const sleep = ms => new Promise(r => setTimeout(r, ms));

function loadPrivateKey() {
  if (P8_CONTENT) {
    const trimmed = P8_CONTENT.trim();
    // Nếu là base64 (không chứa BEGIN), decode trước
    if (!trimmed.includes('-----BEGIN')) {
      return Buffer.from(trimmed, 'base64').toString('utf8');
    }
    return trimmed;
  }
  return fs.readFileSync(P8_PATH, 'utf8');
}

function generateAppleJWT() {
  const privateKey = loadPrivateKey();
  const now = Math.floor(Date.now() / 1000);

  return jwt.sign(
    {
      iss: ISSUER_ID,
      iat: now,
      exp: now + 10 * 60, // 10 phút
      aud: 'appstoreconnect-v1'
    },
    privateKey,
    {
      algorithm: 'ES256',
      header: { kid: KEY_ID, typ: 'JWT' }
    }
  );
}

const api = () => axios.create({
  baseURL: 'https://api.appstoreconnect.apple.com/v1',
  headers: { Authorization: `Bearer ${generateAppleJWT()}` }
});

// ========================
// LOOKUP ASC APP ID BY BUNDLE ID
// ========================
async function lookupAppIdByBundle(client, bundleId) {
  try {
    const res = await client.get(
      `/apps?filter[bundleId]=${encodeURIComponent(bundleId)}&limit=1`
    );
    const app = res.data?.data?.[0];
    if (!app) {
      throw new Error(`Không tìm thấy app với bundle id "${bundleId}" trong App Store Connect`);
    }
    return app.id;
  } catch (err) {
    const detail = err.response?.data?.errors?.[0]?.detail || err.message;
    throw new Error(`Lookup app id thất bại: ${detail}`);
  }
}

// ========================
// SUBMIT BETA REVIEW
// ========================
async function submitForBetaReview(client, buildId) {
  try {
    const res = await client.post('/betaAppReviewSubmissions', {
      data: {
        type: 'betaAppReviewSubmissions',
        relationships: {
          build: {
            data: { type: 'builds', id: buildId }
          }
        }
      }
    });
    console.log('✅ Submitted build for Beta App Review!');
    console.log('   Submission ID:', res.data.data.id);
  } catch (err) {
    const code = err.response?.data?.errors?.[0]?.code;
    const detail = err.response?.data?.errors?.[0]?.detail || err.message;

    if (code === 'ENTITY_UNPROCESSABLE-RELATIONSHIP' || detail.includes('already submitted') || detail.includes('in review')) {
      console.log('ℹ️ Build đã được submit hoặc đang trong quá trình review');
    } else if (detail.includes('missing')) {
      console.warn('⚠️ Submit failed: Thiếu thông tin test (What to Test, Export Compliance, v.v.)');
      console.warn('   Hãy điền đầy đủ Test Information trên App Store Connect web trước!');
    } else {
      console.warn('⚠️ Submit Beta Review failed:', detail);
    }
  }
}

// ========================
// BUILD ASSIGN + SUBMIT
// ========================
async function assignLatestBuildToGroup(client, groupId) {
  try {
    const buildsRes = await client.get(
      `/builds?filter[app]=${IOS_APP_ID}&sort=-uploadedDate&limit=1`
    );

    const latestBuild = buildsRes.data?.data?.[0];
    if (!latestBuild) {
      console.log('⚠️ No builds found for this app');
      return null;
    }

    const buildId = latestBuild.id;
    const version = latestBuild.attributes?.version;
    const uploadedDate = latestBuild.attributes?.uploadedDate;
    const state = latestBuild.attributes?.processingState;

    console.log(`📦 Latest build: ${version} (${state || 'UNKNOWN'}) - Uploaded: ${uploadedDate?.slice(0,10)}`);

    if (state && state !== 'VALID') {
      console.log('⏳ Build chưa sẵn sàng (processingState != VALID), bỏ qua assign');
      return null;
    }

    // Assign build vào group
    try {
      await client.post(
        `/betaGroups/${groupId}/relationships/builds`,
        { data: [{ type: 'builds', id: buildId }] }
      );
      console.log(`✅ Assigned build ${version} vào group ${GROUP_NAME}`);
    } catch (err) {
      const detail = err.response?.data?.errors?.[0]?.detail || '';
      if (detail.includes('already exists') || detail.includes('already assigned')) {
        console.log(`ℹ️ Build ${version} đã được assign trước đó`);
      } else {
        console.warn('⚠️ Assign build failed:', detail || err.message);
        return null;
      }
    }

    await submitForBetaReview(client, buildId);

    return buildId;
  } catch (err) {
    console.warn('⚠️ Could not fetch builds:', err.response?.data || err.message);
    return null;
  }
}

// ========================
// MAIN
// ========================
async function run() {
  const client = api();

  // 0️⃣ Resolve IOS_APP_ID từ bundle id nếu chưa có
  if (!IOS_APP_ID) {
    console.log(`🔎 Đang lookup ASC app id từ bundle id: ${BUNDLE_ID}`);
    IOS_APP_ID = await lookupAppIdByBundle(client, BUNDLE_ID);
    console.log(`   → ASC app id: ${IOS_APP_ID}`);
  }

  // 1️⃣ Get or create External group
  const groupsRes = await client.get(`/betaGroups?filter[app]=${IOS_APP_ID}`);
  let group = groupsRes.data.data.find(g => g.attributes.name === GROUP_NAME);

  if (!group) {
    const createRes = await client.post('/betaGroups', {
      data: {
        type: 'betaGroups',
        attributes: { name: GROUP_NAME, isInternalGroup: false },
        relationships: {
          app: { data: { type: 'apps', id: IOS_APP_ID } }
        }
      }
    });
    group = createRes.data.data;
    console.log(`✅ Created External group "${GROUP_NAME}"`);
  } else {
    console.log(`✅ Found External group "${GROUP_NAME}"`);
  }

  const groupId = group.id;

  // 2️⃣ Assign latest build
  await assignLatestBuildToGroup(client, groupId);

  // 3️⃣ Add / Remove testers
  for (const email of EMAILS) {
    try {
      const testersRes = await client.get(`/betaTesters?filter[email]=${email}`);
      let tester = testersRes.data.data[0];

      if (ACTION === 'remove') {
        if (!tester) {
          console.log(`⚠️ Not found: ${email}`);
          continue;
        }

        // Step 1: Remove from External Testers group
        try {
          await client.delete(
            `/betaGroups/${groupId}/relationships/betaTesters`,
            { data: { data: [{ type: 'betaTesters', id: tester.id }] } }
          );
          console.log(`✅ Removed ${email} from group`);
        } catch (err) {
          console.warn(`⚠️ Could not remove ${email} from group:`, err.response?.data || err.message);
        }

        // Step 2: DELETE tester completely from App Store Connect
        try {
          await client.delete(`/betaTesters/${tester.id}`);
          console.log(`✅ Deleted ${email} completely from App Store Connect`);
        } catch (delErr) {
          const detail = delErr.response?.data?.errors?.[0]?.detail || '';
          if (detail.includes('still assigned') || detail.includes('in use')) {
            console.warn(`⚠️ Cannot delete ${email}: Still assigned to other groups/apps`);
            console.log(`   → Removed from "${GROUP_NAME}" group only`);
          } else {
            console.warn(`⚠️ Could not delete ${email}:`, delErr.response?.data || delErr.message);
          }
        }

        await sleep(300);
        continue;
      }

      // ADD
      if (!tester) {
        const createRes = await client.post('/betaTesters', {
          data: {
            type: 'betaTesters',
            attributes: {
              email,
              firstName: email.split('@')[0],
              lastName: 'Tester'
            },
            relationships: {
              betaGroups: {
                data: [{ type: 'betaGroups', id: groupId }]
              }
            }
          }
        });
        tester = createRes.data.data;
        console.log(`✅ Created + added ${email}`);
      } else {
        await client.post(
          `/betaGroups/${groupId}/relationships/betaTesters`,
          { data: [{ type: 'betaTesters', id: tester.id }] }
        );
        console.log(`✅ Added existing ${email}`);
      }

      await sleep(300); // Rate limit an toàn
    } catch (e) {
      const detail = e.response?.data?.errors?.[0]?.detail || '';
      if (ACTION === 'add' && (detail.includes('already exists') || detail.includes('already assigned'))) {
        console.log(`ℹ️ ${email} đã có trong group`);
      } else {
        console.error(`❌ ${email}`, e.response?.data || e.message);
      }
    }
  }
}

run().catch(err => {
  console.error('🚨 Script error:', err);
  process.exit(1);
});
