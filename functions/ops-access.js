// Only the server-issued role claim is authoritative; there is no trusted
// driver-to-cluster or driver-to-kitchen assignment for these operations.
function requireOpsAdmin(context, HttpsError) {
  if (!context?.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  if (context.auth.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "Administrator role required.");
  }
}

module.exports = { requireOpsAdmin };
