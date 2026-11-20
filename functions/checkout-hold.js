const { checkCheckoutTerms } = require("./checkout-settlement");
const { totalDailyCapacity } = require("./kitchen-plan");

const fields = ["orderId", "uid", "provider", "merchantOrderRef", "amountMinor", "currency",
  "clusterId", "comboSelection", "serviceDates", "hardExpiryDate", "holdExpiresAtMs"];

// Internal, one standard portion per explicitly quoted service day. Inventory
// must already have been allocated to this ledger; a missing day is never seeded.
function createCheckoutHold({ db, now = Date.now }) {
  return async (quote) => {
    if (!quote || Object.keys(quote).some((key) => !fields.includes(key))) {
      throw new Error("Unsupported checkout terms");
    }
    checkCheckoutTerms(quote);
    const terms = { ...quote, serviceDates: [...quote.serviceDates] };
    const orderRef = db.collection("checkout_orders").doc(terms.orderId);
    const days = terms.serviceDates.map((date) => db.collection("checkout_capacity").doc(date));
    return db.runTransaction(async (tx) => {
      const orderDoc = await tx.get(orderRef);
      if (orderDoc.exists) {
        const order = orderDoc.data();
        if (fields.some((key) => key === "serviceDates"
          ? JSON.stringify(order[key]) !== JSON.stringify(terms[key]) : order[key] !== terms[key])) {
          throw new Error("Conflicting checkout terms for this order");
        }
        if (order.status === "SETTLED") return { orderId: terms.orderId, status: "SETTLED" };
        if (order.status !== "HELD") throw new Error("Order cannot be reserved");
      }
      const clock = now();
      if (!Number.isSafeInteger(clock) || clock < 0 || clock >= terms.holdExpiresAtMs) {
        throw new Error("Hold expired or clock unavailable");
      }
      if (!orderDoc.exists) {
        const slots = await Promise.all(days.map((day) => tx.get(day)));
        const available = slots.map((slot) => slot.data()?.remainingPortions);
        if (available.some((n) => !Number.isSafeInteger(n) || n < 1 || n > totalDailyCapacity)) {
          throw new Error("Insufficient or invalid kitchen capacity");
        }
        days.forEach((day, i) => tx.update(day, { remainingPortions: available[i] - 1 }));
        tx.create(orderRef, { ...terms, status: "HELD" });
      }
      return { orderId: terms.orderId, status: "HELD" };
    });
  };
}

module.exports = { createCheckoutHold };
