/**
 * set_admin.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Sets isAdmin: true on a Firestore user document so the user can write to
 * admin-protected collections (magazines, settings, news_reels, etc.).
 *
 * Usage:
 *   node scripts/set_admin.js <firebase-uid>
 *
 * Example:
 *   node scripts/set_admin.js abc123xyz
 *
 * Prerequisites:
 *   1. Place your Firebase service-account key at:
 *        scripts/serviceAccountKey.json
 *   2. Run:  npm install firebase-admin  (inside this scripts/ folder, or the project root)
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');

// ── 1. Resolve the service-account key ───────────────────────────────────────
const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');

let serviceAccount;
try {
  serviceAccount = require(KEY_PATH);
} catch {
  console.error('\n❌  Service account key not found at:');
  console.error(`    ${KEY_PATH}\n`);
  console.error('    Follow Step 2 in the guide to download it from the Firebase Console.\n');
  process.exit(1);
}

// ── 2. Initialise Firebase Admin SDK ─────────────────────────────────────────
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // The project ID is read from the service-account key automatically.
});

const db = admin.firestore();

// ── 3. Read the target UID from the command line ──────────────────────────────
const uid = process.argv[2];

if (!uid || uid.trim() === '') {
  console.error('\n❌  No UID provided.\n');
  console.error('    Usage:  node scripts/set_admin.js <firebase-uid>\n');
  console.error('    Find your UID in Firebase Console → Authentication → Users\n');
  process.exit(1);
}

// ── 4. Write isAdmin: true to Firestore ──────────────────────────────────────
(async () => {
  const userRef = db.collection('users').doc(uid.trim());

  // Safety check — make sure the user document exists first.
  const snap = await userRef.get();
  if (!snap.exists) {
    console.error(`\n❌  No Firestore document found for UID: ${uid}`);
    console.error('    Make sure the user has signed in at least once so their document is created.\n');
    process.exit(1);
  }

  const current = snap.data();
  console.log('\n📋  Current user document fields:');
  console.log(`    displayName : ${current.displayName ?? '(not set)'}`);
  console.log(`    email       : ${current.email ?? '(not set)'}`);
  console.log(`    isAdmin     : ${current.isAdmin ?? false}`);
  console.log(`    isWriter    : ${current.isWriter ?? false}`);

  if (current.isAdmin === true) {
    console.log('\n✅  User is ALREADY an admin. No changes needed.\n');
    process.exit(0);
  }

  // Merge so we don't overwrite any other fields in the document.
  await userRef.set({ isAdmin: true }, { merge: true });

  console.log(`\n✅  Successfully set  isAdmin: true  for UID: ${uid}`);
  console.log('    The user can now write to all admin-protected Firestore collections.\n');
  console.log('    ⚠️  Restart the app on the device to pick up the new permission.\n');

  process.exit(0);
})().catch(err => {
  console.error('\n❌  Unexpected error:', err.message ?? err);
  process.exit(1);
});
