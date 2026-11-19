const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { createSkipMealTicket, scheduleKitchenSplit, failoverKitchenUnit } = require("./meal-scheduling");
const { requireOpsAdmin } = require("./ops-access");

admin.initializeApp();
const db = admin.firestore();

const scheduling = {
  db, HttpsError: functions.https.HttpsError,
  serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
};
exports.skipMealTicket = functions.https.onCall(createSkipMealTicket(scheduling));
exports.autoAggregateKitchenSplit = scheduleKitchenSplit(functions.pubsub, scheduling);

/**
 * 3. broadcastBatchArrival (Callable)
 * Dispatches concurrent Push Notifications to all recipients at a drop point
 */
exports.broadcastBatchArrival = functions.https.onCall(async (data, context) => {
  requireOpsAdmin(context, functions.https.HttpsError);
  const { clusterId } = data || {};
  if (!clusterId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing clusterId.");
  }

  // Fetch recipients at cluster
  const usersSnap = await db
    .collection("users")
    .where("clusterId", "==", clusterId)
    .get();

  const fcmTokens = [];
  usersSnap.forEach((doc) => {
    const user = doc.data();
    if (user.fcmToken) fcmTokens.push(user.fcmToken);
  });

  if (fcmTokens.length > 0) {
    await admin.messaging().sendMulticast({
      tokens: fcmTokens,
      notification: {
        title: "Hungr Tiffin Arrived!",
        body: "Your fresh breakfast packet has been dropped at your hostel / building gate. Please pick up within 90 mins.",
      },
      data: {
        type: "CLUSTER_ARRIVED",
        clusterId: clusterId,
      },
    });
  }

  return { success: true, count: fcmTokens.length };
});

/**
 * 4. reassignKitchenUnitFailover (Callable - Admin only)
 * 1-Tap emergency failover switching to backup central kitchen
 */
exports.reassignKitchenUnitFailover = functions.https.onCall(async (data, context) => {
  requireOpsAdmin(context, functions.https.HttpsError);
  return failoverKitchenUnit(scheduling, data?.unitId);
});
