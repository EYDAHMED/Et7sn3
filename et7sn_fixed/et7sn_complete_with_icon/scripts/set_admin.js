// Grants the `admin` custom claim to a user.
//
// Setup (once):
//   npm install firebase-admin
//   Firebase Console → Project settings → Service accounts → Generate new private key
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json   (never commit this file)
//
// Usage:
//   node scripts/set_admin.js you@example.com

const admin = require('firebase-admin');

admin.initializeApp({ credential: admin.credential.applicationDefault() });

const email = process.argv[2];
if (!email) {
  console.error('Usage: node scripts/set_admin.js <email>');
  process.exit(1);
}

(async () => {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`Admin claim set for ${email} (uid: ${user.uid}).`);
  console.log('They will pick it up on next token refresh (re-open the dashboard or sign in again).');
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
