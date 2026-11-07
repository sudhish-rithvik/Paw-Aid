// lib/core/errors/app_exceptions.dart

/// Base Application Exception
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

/// Authentication specific failures
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code, super.details});
}

/// Thrown when an account is registered but pending approval by an administrator
class AccountPendingApprovalException extends AppAuthException {
  const AccountPendingApprovalException([
    super.message = 'Your NGO account is currently pending administrator verification. Please check back once reviewed.',
  ]) : super(code: 'account-pending-approval');
}

/// Thrown when an account attempts unauthorized access to a privileged role
class UnauthorizedRoleException extends AppAuthException {
  const UnauthorizedRoleException([
    super.message = 'Unauthorized role access. You do not have permission to access this resource.',
  ]) : super(code: 'unauthorized-role');
}

/// Cloud Firestore and database failures
class AppFirestoreException extends AppException {
  const AppFirestoreException(super.message, {super.code, super.details});
}

/// Hardware or device permission failures
class AppPermissionException extends AppException {
  const AppPermissionException(super.message, {super.code, super.details});
}

/// Network or transport failures
class AppNetworkException extends AppException {
  const AppNetworkException(super.message, {super.code, super.details});
}
