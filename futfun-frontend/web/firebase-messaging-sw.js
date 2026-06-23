// Firebase Messaging Service Worker — handles background push notifications on web.
// Os valores abaixo devem ser iguais aos de firebase_web_config.dart.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB7MEH4xE_cnsxKLBvJr0MvOIrknq3SCTE',
  authDomain: 'futfun-385ea.firebaseapp.com',
  projectId: 'futfun-385ea',
  storageBucket: 'futfun-385ea.firebasestorage.app',
  messagingSenderId: '8766160705',
  appId: '1:8766160705:web:865b4db9b116bf1e9dabc0',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'FutFun';
  const body = payload.notification?.body ?? '';
  return self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
