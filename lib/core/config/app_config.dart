/// Application-wide configuration constants.
///
/// [vercelBaseUrl] must be updated after deploying the Vercel project.
/// Format: https://your-project-name.vercel.app  (no trailing slash)
class AppConfig {
  AppConfig._();

  /// Base URL of the deployed Vercel serverless functions project.
  /// Update this after running `vercel deploy` inside /vercel_functions.
  static const String vercelBaseUrl =
      'https://run-campus-connect.vercel.app'; // TODO: replace after deploy
}
