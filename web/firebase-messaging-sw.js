// Firebase Cloud Messaging service worker for OmniLife (web).
//
// The values below are the public web client identifiers from
// lib/firebase_options.dart (DefaultFirebaseOptions.web). They are not
// secrets. Web push only activates when the app is built with
// --dart-define=FCM_VAPID_KEY=<your public VAPID key>; without it the app
// never registers for web push and this worker stays idle.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBcVYnS5djj1W7p2SJGpogjALRkGZC3cDY',
  appId: '1:778334231790:web:aaf25206c0e9cc8158e7ff',
  messagingSenderId: '778334231790',
  projectId: 'gen-lang-client-0609884187',
  authDomain: 'gen-lang-client-0609884187.firebaseapp.com',
  storageBucket: 'gen-lang-client-0609884187.firebasestorage.app',
});

const messaging = firebase.messaging();

// Messages with a `notification` block are shown by the browser itself.
// Data-only messages are turned into a notification here.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  const title = data.title || 'OmniLife';
  self.registration.showNotification(title, {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    data: data,
  });
});

// Open (or focus) the app on the requested screen when a notification is
// clicked. `route` is one of: task, habit, calendar, focus, note.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const routes = {
    task: '/#/tasks',
    habit: '/#/habits',
    calendar: '/#/calendar',
    focus: '/#/focus',
    note: '/#/notes',
  };
  const key = (data.route || data.type || '').replace(/^\//, '');
  const target = routes[key] || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) {
          client.navigate(target);
          return client.focus();
        }
      }
      return clients.openWindow(target);
    })
  );
});
