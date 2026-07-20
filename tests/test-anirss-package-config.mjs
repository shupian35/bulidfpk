import fs from 'node:fs';

const manifest = fs.readFileSync('fnpack/AniRSS/manifest', 'utf8');
const resource = JSON.parse(fs.readFileSync('fnpack/AniRSS/config/resource', 'utf8'));
const privilege = JSON.parse(fs.readFileSync('fnpack/AniRSS/config/privilege', 'utf8'));
const errors = [];

if (!/^disable_authorization_path=false$/m.test(manifest)) {
  errors.push('manifest must set disable_authorization_path=false so fnOS shows folder authorization settings');
}
if (privilege?.defaults?.['run-as'] !== 'package') {
  errors.push('AniRSS must run as the package account');
}
const shares = resource?.['data-share']?.shares;
if (!Array.isArray(shares) || shares.length === 0) {
  errors.push('config/resource must declare data-share.shares');
} else {
  for (const required of ['AniRSS', 'AniRSS/logs', 'AniRSS/torrents']) {
    const share = shares.find((item) => item?.name === required);
    if (!share) {
      errors.push(`missing data share: ${required}`);
    } else if (!share.permission?.rw?.includes('AniRSS')) {
      errors.push(`${required} must grant rw permission to AniRSS`);
    }
  }
}

if (errors.length) {
  console.error('AniRSS package configuration validation failed:');
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log('PASS: AniRSS exposes fnOS folder authorization with required data shares');