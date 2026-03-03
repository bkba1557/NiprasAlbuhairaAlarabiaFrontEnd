importScripts('https://www.gstatic.com/firebasejs/12.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBrZFB8yQOESUT7q2Bm2ARtI9kQ34KrEwg',
  appId: '1:843078322062:web:4986be05fb82bf12b686df',
  messagingSenderId: '843078322062',
  projectId: 'albuhairaalarabia2026',
  authDomain: 'albuhairaalarabia2026.firebaseapp.com',
  storageBucket: 'albuhairaalarabia2026.firebasestorage.app',
  measurementId: 'G-87D3N9N43R',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = (payload && payload.data) || {};
  const notificationTitle =
    (payload && payload.notification && payload.notification.title) ||
    data.title ||
    data.subject ||
    '\u0625\u0634\u0639\u0627\u0631';
  const notificationOptions = {
    body:
      (payload && payload.notification && payload.notification.body) ||
      data.body ||
      data.message ||
      '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    silent: false,
    data: data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = (event.notification && event.notification.data) || {};
  const conversationId =
    (data && data.conversationId && String(data.conversationId)) || '';
  const isChat = data && data.type === 'chat_message' && conversationId;
  const targetUrl = isChat
    ? '/#/chat/conversation?conversationId=' +
      encodeURIComponent(conversationId)
    : '/';

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (
            client.url &&
            client.url.includes(self.location.origin) &&
            'focus' in client
          ) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
        return undefined;
      }),
  );
});
