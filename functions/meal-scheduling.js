const { planKitchenBatch } = require("./kitchen-plan");

const DAY = 24 * 60 * 60 * 1000;
const IST = 330 * 60 * 1000;
// Founder decision (20 Nov 2026): a customer may skip at most 3 meals per pass.
const MAX_SKIPS_PER_PASS = 3;
const istDay = (ms) => Math.floor((ms + IST) / DAY);
const dayIso = (day) => new Date(day * DAY).toISOString();
const dayKey = (day) => dayIso(day).slice(0, 10);

// Dart writes both local ISO calendar values (no offset) and UTC instants.
// Only instants, including Firestore Timestamps, need conversion into IST.
function serviceDay(value) {
  // Timestamp.toDate() can round up into the next day. Truncate instead.
  if (Number.isSafeInteger(value?.seconds) && Number.isInteger(value.nanoseconds) &&
      value.nanoseconds >= 0 && value.nanoseconds < 1e9) {
    return istDay(value.seconds * 1000 + Math.floor(value.nanoseconds / 1e6));
  }
  if (typeof value?.toDate === "function") value = value.toDate();
  if (value instanceof Date) return istDay(value.getTime());
  if (typeof value !== "string") return NaN;
  const iso = /^(\d{4}-\d{2}-\d{2})(?:T(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?(Z|[+-]\d{2}:?\d{2})?)?$/i.exec(value);
  if (!iso) return NaN;
  const midnight = Date.parse(`${iso[1]}T00:00:00Z`);
  // Date.parse can roll an impossible date (e.g. Feb 30) into the next month.
  if (!Number.isFinite(midnight) || dayKey(midnight / DAY) !== iso[1]) return NaN;
  return iso[2] ? istDay(Date.parse(value)) : midnight / DAY;
}

function isDocId(id) {
  return typeof id === "string" && id.trim() !== "" && !id.includes("/");
}

function receipt(id, date) {
  return {
    success: true,
    message: "Ticket skipped successfully with zero refund penalty.",
    newScheduledDate: date,
    newTicketId: id,
  };
}

function createSkipMealTicket({ db, HttpsError, serverTimestamp, now = Date.now }) {
  function checkedDay(value, field) {
    const day = serviceDay(value);
    if (!Number.isFinite(day)) throw new HttpsError("failed-precondition", `Invalid ${field}.`);
    return day;
  }

  return async (data, context) => {
    const uid = context?.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be logged in.");
    if (!isDocId(data?.ticketId)) throw new HttpsError("invalid-argument", "Invalid ticketId.");

    const tickets = db.collection("meal_tickets");
    const source = tickets.doc(data.ticketId);
    return db.runTransaction(async (tx) => {
      const sourceDoc = await tx.get(source);
      if (!sourceDoc.exists) throw new HttpsError("not-found", "Ticket does not exist.");
      const ticket = sourceDoc.data();
      if (ticket.userId !== uid) throw new HttpsError("permission-denied", "Not your ticket.");
      if (!isDocId(ticket.passId)) throw new HttpsError("failed-precondition", "Missing ticket pass.");
      const passDoc = await tx.get(db.collection("passes").doc(ticket.passId));
      if (!passDoc.exists) throw new HttpsError("not-found", "Pass does not exist.");
      const pass = passDoc.data();
      if (pass.userId !== uid) throw new HttpsError("permission-denied", "Not your pass.");

      // A lost response is a read of the original receipt, not another skip.
      if (ticket.status === "SKIPPED" && isDocId(ticket.rescheduledToTicketId) &&
          ticket.rescheduledToTicketId !== source.id) {
        const linked = await tx.get(tickets.doc(ticket.rescheduledToTicketId));
        const replacement = linked.data();
        if (replacement?.userId === uid && replacement.passId === ticket.passId) {
          const day = checkedDay(replacement.deliveryDate, "replacement delivery date");
          return receipt(linked.id, typeof replacement.deliveryDate === "string"
            ? replacement.deliveryDate : dayIso(day));
        }
      }
      if (ticket.status !== "SCHEDULED" || ticket.rescheduledToTicketId != null) {
        throw new HttpsError("failed-precondition", "Ticket is not available to skip.");
      }
      const deliveryDay = checkedDay(ticket.deliveryDate, "delivery date");
      const expiryDay = checkedDay(pass.hardExpiryDate, "pass expiry");

      // A pass has 3/7/15 meals. Reading its ledger in the transaction means
      // two concurrent skips read one another's source and must serialize.
      const ledger = await tx.get(tickets.where("passId", "==", ticket.passId));
      const clock = now();
      if (deliveryDay <= istDay(clock) || new Date(clock + IST).getUTCHours() >= 21) {
        throw new HttpsError("failed-precondition", "403_CUTOFF_EXCEEDED: Meal changes are closed.");
      }
      let tail = deliveryDay;
      let skips = 0;
      for (const doc of ledger.docs) {
        const meal = doc.data();
        if (meal.userId !== uid) continue;
        if (meal.status === "SKIPPED") skips++;
        else if (meal.status === "SCHEDULED" || meal.status === "LOCKED") {
          tail = Math.max(tail, checkedDay(meal.deliveryDate, "pass delivery date"));
        }
      }
      if (skips >= MAX_SKIPS_PER_PASS) {
        throw new HttpsError("failed-precondition",
          `403_SKIP_LIMIT_REACHED: This pass has already used all ${MAX_SKIPS_PER_PASS} skips.`);
      }
      if (tail + 1 > expiryDay) {
        throw new HttpsError("failed-precondition", "403_CEILING_REACHED: Replacement exceeds pass validity.");
      }
      if (!ticket.clusterId || !ticket.comboSelection) {
        throw new HttpsError("failed-precondition", "Ticket is missing its cluster or meal choice.");
      }

      const ref = tickets.doc();
      const date = dayIso(tail + 1);
      const replacement = {
        ticketId: ref.id, passId: ticket.passId, userId: uid,
        clusterId: ticket.clusterId, comboSelection: ticket.comboSelection,
        addOns: ticket.addOns ?? [], slot: ticket.slot ?? "MORNING",
        deliveryDate: date, status: "SCHEDULED", createdAt: serverTimestamp(),
      };
      for (const field of ["clusterName", "bagToken", "specialtyName", "companionMeals"]) {
        if (ticket[field] !== undefined) replacement[field] = ticket[field];
      }
      tx.create(ref, replacement);
      tx.update(source, {
        status: "SKIPPED", skippedAt: serverTimestamp(), rescheduledToTicketId: ref.id,
      });
      return receipt(ref.id, date);
    });
  };
}

async function serviceDayTickets(tx, db, status, day) {
  const query = db.collection("meal_tickets").where("status", Array.isArray(status) ? "in" : "==", status);
  // An offset ISO instant can spell yesterday's or tomorrow's date. Bound
  // both indexed reads, then check the actual IST service day.
  const [strings, timestamps] = await Promise.all([
    tx.get(query.where("deliveryDate", ">=", dayKey(day - 1))
      .where("deliveryDate", "<", dayKey(day + 2))),
    tx.get(query.where("deliveryDate", ">=", new Date(day * DAY - IST))
      .where("deliveryDate", "<", new Date((day + 1) * DAY - IST))),
  ]);
  return [...strings.docs, ...timestamps.docs].filter((doc) => serviceDay(doc.data().deliveryDate) === day);
}

function scheduleKitchenSplit(pubsub, { db, serverTimestamp }) {
  return pubsub.schedule("1 21 * * *").timeZone("Asia/Kolkata").onRun(async (context) => {
    // Pub/Sub preserves the event timestamp on redelivery, even past midnight.
    const day = serviceDay(context.timestamp) + 1;
    if (!Number.isFinite(day)) throw new Error("Missing kitchen schedule date.");
    const date = dayKey(day);
    const summary = db.collection("kitchen_batches").doc(date);
    const count = await db.runTransaction(async (tx) => {
      const batch = await tx.get(summary);
      const tickets = await serviceDayTickets(tx, db, ["SCHEDULED", "LOCKED", "DELIVERED"], day);
      const { locks, totals, changed } = planKitchenBatch(date, batch.data(), tickets);
      for (const { ref, vendorId } of locks) {
        tx.update(ref, { status: "LOCKED", assignedVendorId: vendorId, lockedAt: serverTimestamp() });
      }
      if (!batch.exists) tx.create(summary, { ...totals, isFailoverActive: false, generatedAt: serverTimestamp() });
      else if (changed) tx.update(summary, totals); // Preserve active failover and original timestamps.
      return locks.length || changed ? totals.totalUnits : null;
    });
    if (count !== null) console.log(`21:01 IST split complete for ${date}: ${count} units.`);
    return null;
  });
}

async function failoverKitchenUnit({ db, HttpsError, serverTimestamp, now = Date.now }, unitId) {
  if (unitId !== "aunty_1" && unitId !== "aunty_2") {
    throw new HttpsError("invalid-argument", "Select an existing kitchen unit.");
  }
  const day = istDay(now()) + 1;
  const summary = db.collection("kitchen_batches").doc(dayKey(day));
  const backupCenterAddress = "Central Cloud Backup Hub, Mamillaguda, Khammam";
  await db.runTransaction(async (tx) => {
    const batch = await tx.get(summary);
    if (!batch.exists) throw new HttpsError("not-found", "Tomorrow's kitchen batch does not exist.");
    const { isFailoverActive, failoverUnitId } = batch.data();
    if (isFailoverActive && failoverUnitId !== unitId) {
      // The existing manifest can describe only one failed unit.
      throw new HttpsError("failed-precondition", "This batch already records another unit's failover.");
    }
    const locked = (await serviceDayTickets(tx, db, "LOCKED", day)).filter((doc) => doc.data().assignedVendorId === unitId);
    if (!locked.length && !isFailoverActive) {
      throw new HttpsError("failed-precondition", "This kitchen has no locked meals for tomorrow.");
    }
    for (const doc of locked) {
      tx.update(doc.ref, { assignedVendorId: "backup_hub", pickupAddress: backupCenterAddress });
    }
    if (!isFailoverActive) {
      tx.update(summary, {
        isFailoverActive: true, failoverUnitId: unitId, backupCenterAddress, reroutedAt: serverTimestamp(),
      });
    }
  });
  return { success: true, message: `Unit ${unitId} rerouted to backup hub.` };
}

module.exports = { createSkipMealTicket, scheduleKitchenSplit, failoverKitchenUnit };
