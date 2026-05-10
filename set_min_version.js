/**
 * Run this once to set the minVersionCode in Firestore.
 * Usage: node set_min_version.js
 * 
 * Prerequisites: npm install firebase-admin
 */

const admin = require('firebase-admin');
const serviceAccount = require('./android/app/google-services.json'); // reuse existing config

// Initialize using the project ID from google-services.json
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'vivechanaoj-866db',
});

async function setMinVersion() {
  const db = admin.firestore();
  await db.collection('app_config').doc('version').set({
    minVersionCode: 11,
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj',
  });
  console.log('✅ app_config/version set: minVersionCode = 11');
  process.exit(0);
}

setMinVersion().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
