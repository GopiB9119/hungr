const { createHash } = require("node:crypto");

const PAYMENT_PROVIDER = "razorpay";
const positiveInt = (n) => Number.isSafeInteger(n) && n > 0;
const text = (s, max = 256) => typeof s === "string" && s.length > 0 && s.length <= max &&
  s === s.trim() && !/[\u0000-\u001f\u007f]/.test(s);
const fixedId = (s) => typeof s === "string" && /^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(s);
const currencyCode = (s) => typeof s === "string" && /^[A-Z]{3}$/.test(s);
function calendarDate(s) {
  if (typeof s !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const ms = Date.parse(`${s}T00:00:00Z`);
  return Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === s;
}

// Shared by the hold writer and settlement; lifecycle state and clock are checked separately.
function checkCheckoutTerms(order) {
  if (!fixedId(order?.orderId) || !text(order.uid, 128) || order.provider !== PAYMENT_PROVIDER ||
      !text(order.merchantOrderRef) || !positiveInt(order.amountMinor) || !currencyCode(order.currency)) {
    throw new Error("Invalid checkout terms");
  }
  const { clusterId, comboSelection, serviceDates, hardExpiryDate, holdExpiresAtMs } = order;
  // Keep the entire ledger within one 500-write transaction (claim, pass, order + tickets).
  if (!text(clusterId) || !["A", "B"].includes(comboSelection) || !positiveInt(holdExpiresAtMs) ||
      !calendarDate(hardExpiryDate) || !Array.isArray(serviceDates) ||
      serviceDates.length < 1 || serviceDates.length > 497) throw new Error("Invalid hold terms");
  let previous = "";
  for (const date of serviceDates) {
    if (!calendarDate(date) || date <= previous || date > hardExpiryDate) throw new Error("Invalid held schedule");
    previous = date;
  }
  // The kitchen closes bookings at 21:00 IST on the previous calendar day.
  const firstCutoffMs = Date.parse(`${serviceDates[0]}T00:00:00+05:30`) - 3 * 60 * 60 * 1000;
  if (holdExpiresAtMs > firstCutoffMs) throw new Error("Hold extends past the kitchen cutoff");
}

// Internal only. The hold writer atomically reserves one portion per serviceDate
// and creates checkout_orders/{orderId} with immutable terms and status HELD.
// lookupCapture must independently verify the Razorpay capture, account and order metadata.
function createCheckoutSettlement({ db, lookupCapture, serverTimestamp, now = Date.now }) {
  return async ({ orderId, provider, paymentId }) => {
    if (!fixedId(orderId) || provider !== PAYMENT_PROVIDER || !text(paymentId)) throw new Error("Invalid checkout reference");
    // No provider I/O in a Firestore retry. Only the authenticated lookup may supply these fields.
    const capture = await lookupCapture({ provider, paymentId });
    if (capture?.status !== "CAPTURED" || capture.provider !== provider || capture.paymentId !== paymentId ||
        capture.orderId !== orderId) throw new Error("Unverified capture");
    const { uid, merchantOrderRef, amountMinor, currency } = capture;
    const key = createHash("sha256").update(JSON.stringify([provider, paymentId])).digest("hex");
    const claimRef = db.collection("checkout_payment_claims").doc(key);
    const orderRef = db.collection("checkout_orders").doc(orderId);
    const passId = `checkout-${orderId}`;

    return db.runTransaction(async (tx) => {
      const [orderDoc, claimDoc] = await Promise.all([tx.get(orderRef), tx.get(claimRef)]);
      const order = orderDoc.data();
      if (!order || order.orderId !== orderId || order.provider !== provider || order.uid !== uid ||
          order.merchantOrderRef !== merchantOrderRef || order.amountMinor !== amountMinor ||
          order.currency !== currency) throw new Error("Capture does not match reserved order");
      checkCheckoutTerms(order);

      const clock = now();
      if (!Number.isSafeInteger(clock) || clock < 0) throw new Error("Invalid settlement clock");
      const receipt = { orderId, passId };
      const creditReceipt = { orderId, passId: null, creditId: key, status: "CREDITED" };
      const claim = claimDoc.data();
      if (claimDoc.exists) {
        if (claim.orderId === orderId && claim.provider === provider && claim.paymentId === paymentId) {
          if (claim.outcome === "CREDIT" && claim.creditId === key) return creditReceipt;
          if (claim.outcome === undefined && claim.creditId === undefined && order.status === "SETTLED" &&
              order.paymentId === paymentId && order.passId === passId) return receipt;
        }
        throw new Error("Payment already claimed");
      }

      let reason;
      if (order.status === "SETTLED") {
        if (!text(order.paymentId) || order.paymentId === paymentId) throw new Error("Conflicting settlement");
        reason = "DUPLICATE_PAYMENT";
      } else if (order.status !== "HELD" || clock >= order.holdExpiresAtMs) {
        reason = "HOLD_NOT_ACTIVE";
      } else if (order.paymentId != null || order.passId != null) throw new Error("Order not held");

      const createdAt = serverTimestamp();
      if (reason) {
        tx.create(claimRef, { orderId, provider, paymentId, outcome: "CREDIT", creditId: key });
        tx.create(db.collection("customer_credits").doc(key), {
          creditId: key, userId: uid, amountMinor, currency, provider, paymentId, orderId, reason, status: "AVAILABLE", createdAt,
        });
        return creditReceipt;
      }
      tx.create(claimRef, { orderId, provider, paymentId });
      tx.create(db.collection("passes").doc(passId), {
        passId, orderId, userId: uid, hardExpiryDate: order.hardExpiryDate, createdAt,
      });
      for (const date of order.serviceDates) {
        const ticketId = `${passId}_${date}`;
        tx.create(db.collection("meal_tickets").doc(ticketId), {
          ticketId, passId, userId: uid, deliveryDate: `${date}T00:00:00.000Z`, status: "SCHEDULED",
          clusterId: order.clusterId, comboSelection: order.comboSelection, addOns: [], slot: "MORNING", createdAt,
        });
      }
      tx.update(orderRef, { status: "SETTLED", passId, paymentId, settledAt: createdAt });
      return receipt;
    });
  };
}

module.exports = { PAYMENT_PROVIDER, checkCheckoutTerms, createCheckoutSettlement };
