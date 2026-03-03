import 'dart:html' as html;

void setAuthToken(String token) {
  html.window.localStorage['auth_token'] = token;
}

void clearAuthToken() {
  html.window.localStorage.remove('auth_token');
}
