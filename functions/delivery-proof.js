// Founder rule (round 2): QR scan is optional, so the rider's door photo is the
// delivery proof. The rider app only uploads the photo; this server trigger is
// the only writer that can mark a meal DELIVERED.
const PROOF_PATH = /^delivery_proofs\/([A-Za-z0-9_-]{1,160})\/proof$/;
const IMAGE_TYPE = /^image\/(jpeg|png|webp)$/;
const MAX_BYTES = 5 * 1024 * 1024;

async function finalizeDeliveryProof({ db, serverTimestamp, clearDownloadTokens, log = console }, object) {
  const match = PROOF_PATH.exec(object?.name || "");
  if (!match) return "NOT_A_PROOF";
  try {
    const size = Number(object.size);
    if (!IMAGE_TYPE.test(object.contentType || "") || !(size > 0 && size < MAX_BYTES)) {
      log.warn(`Delivery proof ${object.name} refused: ${object.contentType}, ${object.size} bytes.`);
      return "REJECTED_FILE";
    }
    const ref = db.collection("meal_tickets").doc(match[1]);
    return await db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      const meal = doc.exists ? doc.data() : null;
      if (meal?.status === "DELIVERED" && meal.dropProofPath === object.name) return "ALREADY_DELIVERED";
      if (meal?.status !== "LOCKED") {
        log.warn(`Delivery proof ${object.name} ignored: ticket status is ${meal ? meal.status : "missing"}.`);
        return "IGNORED";
      }
      tx.update(ref, { status: "DELIVERED", dropProofPath: object.name, deliveredAt: serverTimestamp() });
      return "DELIVERED";
    });
  } finally {
    // A token URL opens the photo for anyone who has it, bypassing Storage rules.
    if (object.metadata?.firebaseStorageDownloadTokens) await clearDownloadTokens(object);
  }
}

module.exports = { finalizeDeliveryProof };
