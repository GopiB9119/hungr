const CAPACITY = 50;
const vendors = ["aunty_1", "aunty_2"];

// Each order is indivisible. At most 51 possible loads for kitchen 1 need
// consideration; greedy placement can report a shortage on a feasible day.
function partition(orders, first, second, total) {
  const groups = new Map([[first, []]]);
  for (const order of orders) {
    for (const [load, group] of [...groups]) {
      const next = load + order.portions;
      if (next <= CAPACITY && !groups.has(next)) groups.set(next, [...group, order]);
    }
  }
  const loads = [...groups.keys()].filter((load) => total - load <= CAPACITY && total - load >= second);
  loads.sort((a, b) => Math.abs(2 * a - total) - Math.abs(2 * b - total) || b - a);
  return loads.length ? new Set(groups.get(loads[0])) : null;
}

function planKitchenBatch(date, previous, docs) {
  function reconcile(reason) {
    throw new Error(`KITCHEN_RECONCILE ${date}: ${reason}. Check the manifest against paid tickets and rerun; no changes committed.`);
  }
  const failed = previous?.isFailoverActive === true ? previous.failoverUnitId : null;
  if ((previous?.date !== undefined && previous.date !== date) ||
      (previous?.isFailoverActive === true ? !vendors.includes(failed) : previous?.failoverUnitId != null) ||
      (previous?.isFailoverActive !== undefined && typeof previous.isFailoverActive !== "boolean")) {
    reconcile("Inconsistent batch date or failover details");
  }

  const units = vendors.map((vendorId) => ({ vendorId, total: 0, optionA: 0, optionB: 0 }));
  const pending = [], locks = [];
  function assign(order, unit) {
    unit.total += order.portions;
    unit[order.option] += order.portions;
    if (order.scheduled) locks.push({ ref: order.ref, vendorId: unit.vendorId });
  }
  for (const doc of docs) {
    const meal = doc.data();
    const companions = meal.companionMeals ?? 0;
    if (!Number.isSafeInteger(companions) || companions < 0 || !Number.isSafeInteger(companions + 1) ||
        !["A", "B"].includes(meal.comboSelection)) {
      reconcile("Missing combo or invalid companion quantity");
    }
    const order = {
      ref: doc.ref, portions: 1 + companions, option: `option${meal.comboSelection}`,
      scheduled: meal.status === "SCHEDULED",
    };
    if (order.scheduled && failed) reconcile("New orders during active failover need an operator-confirmed route");
    if (order.scheduled && meal.assignedVendorId == null) {
      pending.push(order);
    } else {
      const vendor = meal.assignedVendorId === "backup_hub" ? failed : meal.assignedVendorId;
      const unit = units.find((u) => u.vendorId === vendor);
      if (!unit) reconcile("An assigned meal has no verifiable original kitchen");
      if (meal.status === "LOCKED" && meal.assignedVendorId === failed) reconcile("Complete the recorded failover first");
      assign(order, unit); // Pinned, locked and delivered orders keep their existing kitchen.
    }
  }

  // Old manifests counted tickets rather than portions, and could be empty
  // after a redelivery. Grow supported totals; never erase unexplained counts.
  function verify(count, observed) {
    if (count !== undefined && (!Number.isSafeInteger(count) || count < 0 || count > observed)) {
      reconcile("Recorded quantities are not backed by assigned tickets");
    }
  }
  verify(previous?.totalUnits, units[0].total + units[1].total);
  units.forEach((unit, i) => {
    const stored = previous?.[`unit${i + 1}`];
    if (stored !== undefined && (!stored || typeof stored !== "object" || Array.isArray(stored) ||
        (stored.vendorId !== undefined && stored.vendorId !== unit.vendorId))) {
      reconcile("A recorded kitchen does not match the assigned tickets");
    }
    for (const key of ["total", "optionA", "optionB"]) verify(stored?.[key], unit[key]);
  });

  const totalUnits = pending.reduce((n, o) => n + o.portions, units[0].total + units[1].total);
  const first = totalUnits <= 2 * CAPACITY && units.every((u) => u.total <= CAPACITY)
    ? partition(pending, units[0].total, units[1].total, totalUnits) : null;
  if (!first) {
    throw new Error(`KITCHEN_CAPACITY ${date}: ${totalUnits} paid portions cannot fit whole orders in two kitchens of ${CAPACITY}. Resolve capacity before rerunning; no tickets changed.`);
  }
  for (const order of pending) assign(order, first.has(order) ? units[0] : units[1]);

  const totals = { date, totalUnits };
  let changed = previous?.date !== date || previous?.totalUnits !== totalUnits;
  units.forEach((unit, i) => {
    const key = `unit${i + 1}`;
    if (Object.entries(unit).some(([k, v]) => previous?.[key]?.[k] !== v)) changed = true;
    totals[key] = { ...previous?.[key], ...unit };
  });
  return { locks, totals, changed };
}

module.exports = { planKitchenBatch };
