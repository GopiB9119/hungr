// ==============================================================================
// HUNGR OPERATIONS COMMAND - FIREBASE WEB CONFIGURATION
// ==============================================================================
// To connect your live Firebase project:
// 1. Go to Firebase Console -> Project Settings -> General -> Your apps -> Web app
// 2. Paste your web app configuration keys below.
// 3. Deploy anytime via: firebase deploy --only hosting
// ==============================================================================

const firebaseConfig = {
  apiKey: "AIzaSyYOUR_API_KEY_HERE",
  authDomain: "hungr-app.firebaseapp.com",
  projectId: "hungr-app",
  storageBucket: "hungr-app.appspot.com",
  messagingSenderId: "1234567890",
  appId: "1:1234567890:web:abcdef123456"
};

const isFirebaseConfigured = Boolean(firebaseConfig.apiKey && !firebaseConfig.apiKey.includes('YOUR_API_KEY'));
let isFirebaseAvailable = false;
let db = null;
let auth = null;

try {
  if (isFirebaseConfigured && typeof firebase !== 'undefined') {
    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }
    db = firebase.firestore();
    auth = firebase.auth();
    isFirebaseAvailable = true;
    console.log('✅ [Hungr Web Admin] Firebase Cloud Firestore initialized successfully!');
  } else if (isFirebaseConfigured) {
    console.warn('[Hungr Web Admin] Firebase SDK unavailable; cloud changes cannot be saved.');
  } else {
    console.info('[Hungr Web Admin] Browser preview only. Changes are not published.');
  }
} catch (e) {
  console.error('❌ [Hungr Web Admin] Firebase initialization error:', e);
}
