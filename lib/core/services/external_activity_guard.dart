/// Marks a short-lived external activity, such as the device camera.
/// The admin lock must not treat this as the user leaving the app.
class ExternalActivityGuard {
  ExternalActivityGuard._();

  static bool isActive = false;
}
