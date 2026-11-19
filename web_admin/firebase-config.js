// ==============================================================================
// HUNGR OPERATIONS COMMAND - FIREBASE WEB CONFIGURATION
// ==============================================================================
// Connected to Firebase Project: hungr-6b059
// ==============================================================================

const firebaseConfig = {
  apiKey: "AIzaSyCgbmV7pyFHS9qcDjJFdxdmcDKOaE6uDBw",
  authDomain: "hungr-6b059.firebaseapp.com",
  projectId: "hungr-6b059",
  storageBucket: "hungr-6b059.firebasestorage.app",
  messagingSenderId: "746415225267",
  appId: "1:746415225267:web:hungrweboperations"
};

let isFirebaseAvailable = false;
let db = null;
let auth = null;

try {
  if (
    typeof firebase !== 'undefined' &&
    firebaseConfig.apiKey &&
    !firebaseConfig.apiKey.includes('YOUR_API_KEY')
  ) {
    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }
    db = firebase.firestore();
    auth = firebase.auth();
    isFirebaseAvailable = true;
    console.log('✅ [Hungr Web Admin] Firebase Cloud Firestore initialized successfully for hungr-6b059!');
  } else {
    console.warn('⚠️ [Hungr Web Admin] Running in Local Cache Mode. Set your Firebase Web Config in firebase-config.js to activate live cloud sync.');
  }
} catch (e) {
  console.error('❌ [Hungr Web Admin] Firebase initialization error:', e);
}
