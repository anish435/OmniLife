/// Turns Firebase Auth error codes into short, plain sentences a person
/// can act on. Raw SDK messages (which can include codes, URLs or stack
/// details) must never reach the screen.
String friendlyAuthMessage(String? code, {String? fallback}) {
  switch (code) {
    case 'invalid-email':
      return 'That email address does not look right. Please check it.';
    case 'user-disabled':
      return 'This account has been turned off. Contact support for help.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'Email or password is incorrect.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in.';
    case 'weak-password':
      return 'Please choose a longer password with at least 6 characters.';
    case 'operation-not-allowed':
      return 'This way of signing in is not turned on yet.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a few minutes and try again.';
    case 'network-request-failed':
      return 'No internet connection. Check your network and try again.';
    case 'requires-recent-login':
      return 'Please sign in again to continue.';
    case 'account-exists-with-different-credential':
      return 'This email is already used with a different sign-in method.';
    case 'popup-blocked':
      return 'Your browser blocked the sign-in window. Allow pop-ups and retry.';
    case 'missing-email':
      return 'Please enter your email address.';
    case 'internal-error':
    case 'unknown':
      return 'Something went wrong. Please try again.';
  }
  return fallback ?? 'Something went wrong. Please try again.';
}

/// Message for an account action when sign-in is not set up on this build.
const authUnavailableMessage =
    'Sign-in is not available right now. Please try again later.';
