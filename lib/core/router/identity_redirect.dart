import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'route_names.dart';

Future<String?> identityRedirect(String path, AuthViewModel auth) async {
  if (path == RouteNames.splash || path == RouteNames.legalPolicy) return null;
  await auth.ready;
  if (path == RouteNames.phoneAuth || path == RouteNames.otpVerify) {
    if (auth.hasVerifiedSession) {
      return auth.hasSavedGate ? RouteNames.storefront : RouteNames.clusterSelection;
    }
    if (path == RouteNames.otpVerify && !auth.hasPendingCode) return RouteNames.phoneAuth;
    return null;
  }
  if (!auth.hasVerifiedSession) return RouteNames.phoneAuth;
  if (!auth.hasSavedGate && (path == RouteNames.storefront || path.startsWith('${RouteNames.storefront}/'))) {
    return RouteNames.clusterSelection;
  }
  return null;
}
