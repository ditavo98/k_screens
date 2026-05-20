/**
 * github-secrets.js
 *
 * Utility để set GitHub Repository Secrets từ code (form, API, CLI...)
 * Dùng GitHub REST API + tweetnacl để encrypt.
 *
 * Cách dùng:
 *   import { setGitHubSecrets } from './github-secrets.js';
 *
 *   await setGitHubSecrets({
 *     githubToken: 'ghp_xxxx',           // PAT với quyền "repo"
 *     owner: 'ditavo98',
 *     repo: 'k_screens',
 *     secrets: {
 *       ASC_KEY_ID: 'XXXXXXXXXX',
 *       ASC_ISSUER_ID: 'xxxxx-xxxx-xxxx',
 *       ASC_PRIVATE_KEY_B64: 'LS0tLS1CRUdJTi...',
 *       APPLE_TEAM_ID: 'XXXXXXXXXX',
 *       MATCH_GIT_URL: 'git@github.com:org/certs.git',
 *       MATCH_PASSWORD: 'your-password',
 *     },
 *   });
 *
 * Yêu cầu: npm install tweetnacl tweetnacl-util
 *           (hoặc dùng CDN nếu browser)
 */

import nacl from 'tweetnacl';
import {
  decodeBase64,
  encodeBase64,
  decodeUTF8,
} from 'tweetnacl-util';

const API = 'https://api.github.com';

/**
 * Lấy public key của repo (dùng để encrypt secret)
 */
async function getRepoPublicKey({ githubToken, owner, repo }) {
  const res = await fetch(
    `${API}/repos/${owner}/${repo}/actions/secrets/public-key`,
    {
      headers: {
        Authorization: `Bearer ${githubToken}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    }
  );

  if (!res.ok) {
    const body = await res.text();
    throw new Error(
      `Lấy public key thất bại (${res.status}): ${body}`
    );
  }

  return res.json(); // { key_id, key }
}

/**
 * Encrypt secret value bằng repo public key (libsodium sealed box)
 */
function encryptSecret(publicKeyB64, secretValue) {
  const publicKey = decodeBase64(publicKeyB64);
  const messageBytes = decodeUTF8(secretValue);
  const encrypted = nacl.box.seal(messageBytes, publicKey);
  return encodeBase64(encrypted);
}

/**
 * Set 1 secret lên repo
 */
async function setOneSecret({
  githubToken,
  owner,
  repo,
  secretName,
  encryptedValue,
  keyId,
}) {
  const res = await fetch(
    `${API}/repos/${owner}/${repo}/actions/secrets/${secretName}`,
    {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${githubToken}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        encrypted_value: encryptedValue,
        key_id: keyId,
      }),
    }
  );

  if (!res.ok && res.status !== 204) {
    const body = await res.text();
    throw new Error(
      `Set secret '${secretName}' thất bại (${res.status}): ${body}`
    );
  }

  return true;
}

// ─── PUBLIC API ──────────────────────────────────────────────────────────────

/**
 * Set nhiều secrets cùng lúc lên GitHub repo.
 *
 * @param {Object} config
 * @param {string} config.githubToken  - GitHub PAT (cần quyền "repo")
 * @param {string} config.owner        - GitHub username / org
 * @param {string} config.repo         - Tên repo
 * @param {Object} config.secrets      - { SECRET_NAME: 'value', ... }
 * @returns {Promise<Object>} - { success: boolean, results: [...] }
 */
export async function setGitHubSecrets({
  githubToken,
  owner,
  repo,
  secrets,
}) {
  // Bước 1: Lấy public key
  const { key, key_id } = await getRepoPublicKey({
    githubToken,
    owner,
    repo,
  });

  // Bước 2: Encrypt và set từng secret
  const results = [];
  for (const [name, value] of Object.entries(secrets)) {
    if (!value || value.trim() === '') {
      results.push({ name, status: 'skipped', reason: 'empty' });
      continue;
    }

    try {
      const encrypted = encryptSecret(key, value);
      await setOneSecret({
        githubToken,
        owner,
        repo,
        secretName: name,
        encryptedValue: encrypted,
        keyId: key_id,
      });
      results.push({ name, status: 'ok' });
    } catch (err) {
      results.push({ name, status: 'error', error: err.message });
    }
  }

  return {
    success: results.every(
      (r) => r.status === 'ok' || r.status === 'skipped'
    ),
    results,
  };
}

/**
 * Trigger workflow dispatch sau khi set secrets xong.
 *
 * @param {Object} config
 * @param {string} config.githubToken
 * @param {string} config.owner
 * @param {string} config.repo
 * @param {string} [config.ref='main']       - Branch
 * @param {string} [config.platforms='ios android']
 * @returns {Promise<boolean>}
 */
export async function triggerMobileCIWorkflow({
  githubToken,
  owner,
  repo,
  ref = 'main',
  platforms = 'ios android',
  skipUpload = false,
}) {
  const res = await fetch(
    `${API}/repos/${owner}/${repo}/actions/workflows/mobile-ci.yml/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${githubToken}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ref,
        inputs: {
          platforms,
          skip_upload: String(skipUpload),
        },
      }),
    }
  );

  if (!res.ok && res.status !== 204) {
    const body = await res.text();
    throw new Error(
      `Trigger workflow thất bại (${res.status}): ${body}`
    );
  }

  return true;
}

/**
 * Danh sách tất cả secrets cần cho mobile-ci.
 * Dùng để render form fields tự động.
 */
export const MOBILE_CI_SECRETS = [
  {
    key: 'ASC_KEY_ID',
    label: 'App Store Connect Key ID',
    required: true,
    sensitive: false,
    placeholder: 'XXXXXXXXXX',
    help: 'Tạo tại: App Store Connect → Users and Access → Integrations → Keys',
  },
  {
    key: 'ASC_ISSUER_ID',
    label: 'App Store Connect Issuer ID',
    required: true,
    sensitive: false,
    placeholder: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    help: 'Hiển thị ở đầu trang Keys',
  },
  {
    key: 'ASC_PRIVATE_KEY_B64',
    label: 'Private Key (.p8) — Base64',
    required: true,
    sensitive: true,
    placeholder: 'LS0tLS1CRUdJTi...',
    help: 'Chạy: base64 -i AuthKey_XXX.p8 | tr -d "\\n"',
  },
  {
    key: 'APPLE_TEAM_ID',
    label: 'Apple Developer Team ID',
    required: true,
    sensitive: false,
    placeholder: 'XXXXXXXXXX',
    help: 'developer.apple.com → Membership → Team ID',
  },
  {
    key: 'MATCH_GIT_URL',
    label: 'Match Git Repository URL',
    required: false,
    sensitive: false,
    placeholder: 'git@github.com:org/certs.git',
    help: 'Repo riêng để lưu certificates (Fastlane Match)',
  },
  {
    key: 'MATCH_PASSWORD',
    label: 'Match Encryption Password',
    required: false,
    sensitive: true,
    placeholder: '',
    help: 'Mật khẩu để encrypt/decrypt certificates trong match repo',
  },
  {
    key: 'MATCH_SSH_KEY',
    label: 'SSH Private Key (cho Match repo)',
    required: false,
    sensitive: true,
    placeholder: '-----BEGIN OPENSSH PRIVATE KEY-----',
    help: 'SSH key để clone match repo (nếu dùng SSH URL)',
  },
];
