importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

// This is a placeholder to prevent "MIME type" errors on web platforms.
// Actual messaging is handled via the Flutter side or Firebase auto-discovery.
firebase.initializeApp({
  apiKey: "placeholder",
  projectId: "placeholder",
  messagingSenderId: "placeholder",
  appId: "placeholder"
});

const messaging = firebase.messaging();
