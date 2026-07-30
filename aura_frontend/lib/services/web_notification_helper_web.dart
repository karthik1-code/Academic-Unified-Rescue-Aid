import 'dart:html' as html;

void requestWebNotificationPermission() {
  if (html.Notification.permission != 'granted') {
    html.Notification.requestPermission();
  }
}

void showWebNotification(String title, String body) {
  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body);
  } else {
    html.Notification.requestPermission().then((permission) {
      if (permission == 'granted') {
        html.Notification(title, body: body);
      }
    });
  }
}
