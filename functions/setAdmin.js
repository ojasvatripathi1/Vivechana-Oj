const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2]; // UID from command line

admin.auth().setCustomUserClaims(uid, { admin: true })
    .then(() => {
        console.log('✅ Admin claim set for UID:', uid);
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Error setting admin claim:', error);
        process.exit(1);
    });