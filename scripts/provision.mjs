import { setTimeout as sleep } from 'node:timers/promises';

const KEY = 'AIzaSyCJ_XBINyRIeQ8ytAsK-g5ubGOnyPsZNS8';
const PROJECT = 'aqua-link-ph';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const OWNER = process.env.FB_OWNER_TOKEN;

const rand = (() => {
  let s = Date.now() % 2147483647;
  return () => (s = (s * 48271) % 2147483647) / 2147483647;
})();
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));
const pick = (arr) => arr[between(0, arr.length - 1)];

const S = (v) => ({ stringValue: String(v) });
const D = (v) => ({ doubleValue: v });
const I = (v) => ({ integerValue: String(v) });
const B = (v) => ({ booleanValue: v });
const T = (d) => {
  if (!(d instanceof Date) || !Number.isFinite(d.getTime())) {
    console.error('T() received invalid value:', String(d), '| ctor:', d?.constructor?.name);
    console.error(new Error().stack);
    process.exit(2);
  }
  return { timestampValue: d.toISOString() };
};
const NU = { nullValue: null };

async function idp(path, body) {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/${path}?key=${KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (!r.ok) {
    if (j.error?.message === 'EMAIL_EXISTS') return null;
    throw new Error(`${path}: ${JSON.stringify(j)}`);
  }
  return j;
}

async function ownerPatch(path, fields) {
  const r = await fetch(`${BASE}/${path}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${OWNER}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!r.ok) throw new Error(`ownerPatch ${path}: ${await r.text()}`);
  return r.json();
}

async function authedWrite(token, path, fields, method = 'POST') {
  const url = method === 'POST' ? `${BASE}/${path}` : `${BASE}/${path}`;
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!r.ok) throw new Error(`authedWrite ${path}: ${await r.text()}`);
  return r.json();
}

async function chunk(items, fn, size = 8) {
  for (let i = 0; i < items.length; i += size) {
    await Promise.all(items.slice(i, i + size).map(fn));
  }
}

async function ownerList(coll) {
  const names = [];
  let page = '';
  for (;;) {
    const url = `${BASE}/${coll}?pageSize=300${page ? `&pageToken=${page}` : ''}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${OWNER}` } });
    if (!r.ok) return names;
    const j = await r.json();
    for (const d of j.documents ?? []) {
      names.push({ name: d.name.slice(BASE.length + 1), fields: d.fields ?? {} });
    }
    if (!j.nextPageToken) return names;
    page = j.nextPageToken;
  }
}

async function ownerDelete(path) {
  const r = await fetch(`${BASE}/${path}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${OWNER}` },
  });
  if (!r.ok && r.status !== 404) throw new Error(`ownerDelete ${path}: ${await r.text()}`);
}

const now = () => new Date();
const iso = (d) => d;

async function main() {
  console.log('1 · Creating auth accounts…');
  const accounts = {};
  for (const [email, name] of [
    ['admin@aquaph.test', 'Station Administrator'],
    ['staff@aquaph.test', 'Miguel Ramos'],
    ['maria@aquaph.test', 'Maria Santos'],
  ]) {
    let res = await idp('accounts:signUp', { email, password: 'Aqua123!', returnSecureToken: true });
    if (!res) {
      res = await idp('accounts:signInWithPassword', { email, password: 'Aqua123!', returnSecureToken: true });
      console.log(`   ${email} already existed (signed in to verify)`);
    } else {
      console.log(`   ${email} created`);
    }
    accounts[email] = { uid: res.localId };
  }
  const ADMIN_UID = accounts['admin@aquaph.test'].uid;
  const STAFF_UID = accounts['staff@aquaph.test'].uid;
  const MARIA_UID = accounts['maria@aquaph.test'].uid;

  console.log('2 · Writing profile documents (owner credentials)…');
  const ts = T(now());
  await ownerPatch(`users/${ADMIN_UID}`, {
    uid: S(ADMIN_UID), name: S('Station Administrator'), email: S('admin@aquaph.test'),
    role: S('admin'), phone: S('0917 555 0143'), address: S('Purok 2, Brgy. San Isidro'),
    disabled: B(false), createdAt: ts,
  });
  await ownerPatch(`users/${STAFF_UID}`, {
    uid: S(STAFF_UID), name: S('Miguel Ramos'), email: S('staff@aquaph.test'),
    role: S('staff'), phone: S('09171231001'), address: S(''),
    disabled: B(false), createdAt: ts,
  });
  await ownerPatch(`users/${MARIA_UID}`, {
    uid: S(MARIA_UID), name: S('Maria Santos'), email: S('maria@aquaph.test'),
    role: S('customer'), phone: S('09171230001'), address: S('12 Rizal St., Brgy. San Isidro'),
    disabled: B(false), createdAt: ts,
  });
  await ownerPatch(`customers/${MARIA_UID}`, {
    userId: S(MARIA_UID), fullName: S('Maria Santos'), contactNumber: S('09171230001'),
    address: S('12 Rizal St., Brgy. San Isidro'), notes: S(''), createdAt: ts, updatedAt: ts,
  });
  await ownerPatch('config/bootstrap', { adminClaimed: B(true), at: ts });
  console.log('   profiles ready (admin / staff / customer)');

  console.log('2b · Cleaning any partial seed data…');
  for (const coll of ['inventory', 'orders', 'sales', 'gallons', 'expenses', 'notifications']) {
    const docs = await ownerList(coll);
    for (const d of docs) await ownerDelete(d.name);
    if (docs.length) console.log(`   ${coll}: removed ${docs.length}`);
  }
  const custDocs = await ownerList('customers');
  let removedCusts = 0;
  for (const d of custDocs) {
    if (d.fields.userId?.stringValue) continue;
    await ownerDelete(d.name);
    removedCusts++;
  }
  if (removedCusts) console.log(`   customers: removed ${removedCusts} walk-in records`);

  console.log('3 · Signing in as admin to seed demo data through security rules…');
  const login = await idp('accounts:signInWithPassword', {
    email: 'admin@aquaph.test', password: 'Aqua123!', returnSecureToken: true,
  });
  const TOKEN = login.idToken;
  console.log('   admin session acquired');

  console.log('4 · Inventory products…');
  const inventoryDefs = [
    ['Purified Water (Round 5-gal)', 'Refill', 40, 120, 20, 'gallons'],
    ['Distilled Water (Round 5-gal)', 'Refill', 45, 85, 20, 'gallons'],
    ['Alkaline Water (Round 5-gal)', 'Refill', 55, 14, 15, 'gallons'],
    ['Empty Round Containers', 'Containers', 350, 60, 10, 'pcs'],
    ['Bottle Caps & Seals', 'Supplies', 5, 480, 100, 'pcs'],
  ];
  const products = [];
  for (const [name, category, price, qty, reorder, unit] of inventoryDefs) {
    const res = await authedWrite(TOKEN, 'inventory', {
      name: S(name), category: S(category), unitPrice: D(price),
      quantityOnHand: I(qty), reorderLevel: I(reorder), unitLabel: S(unit),
      updatedAt: T(now()),
    });
    products.push({ id: res.name.split('/').pop(), name, price });
  }

  console.log('5 · Walk-in customers…');
  const walkins = [
    ['Juan Dela Cruz', '09171230002', '45 Mabini Ave., Purok 3'],
    ['Ana Reyes', '09171230003', '8 Bonifacio Rd., Brgy. Malinao'],
    ['Carlo Mendoza', '09171230004', '23 Aguinaldo Hwy., Purok 5'],
    ['Grace Lim', '09171230005', '77 Luna St., Brgy. Poblacion'],
    ['Rico Torres', '09171230006', '31 Magsaysay Dr., Purok 2'],
  ];
  const customerByName = { 'Maria Santos': MARIA_UID };
  for (const [fullName, phone, address] of walkins) {
    const res = await authedWrite(TOKEN, 'customers', {
      userId: NU, fullName: S(fullName), contactNumber: S(phone),
      address: S(address), notes: S(''), createdAt: ts, updatedAt: ts,
    });
    customerByName[fullName] = res.name.split('/').pop();
  }

  console.log('6 · Gallons GLN-0001 … GLN-0030…');
  const gallonJobs = [];
  for (let i = 1; i <= 30; i++) {
    const code = `GLN-${String(i).padStart(4, '0')}`;
    gallonJobs.push(() => authedWrite(TOKEN, `gallons/${code}`, {
      gallonId: S(code), qrCodeValue: S(code), status: S('available'),
      currentCustomerId: NU, currentCustomerName: NU, currentOrderId: NU,
      createdAt: T(now()), updatedAt: T(now()),
    }, 'PATCH'));
  }
  await chunk(gallonJobs, (f) => f(), 10);
  console.log('   30 gallons registered');

  console.log('7 · Historical orders + sales (35 days)…');
  const names = Object.keys(customerByName);
  const orderJobs = [];
  let orderCount = 0;
  const today = new Date();

  function orderFields(cust, product, qty, delivery, when, status, paid, method, extra = {}) {
    const total = product.price * qty + (delivery ? 20 : 0);
    return {
      customerId: S(customerByName[cust]),
      userId: cust === 'Maria Santos' ? S(MARIA_UID) : NU,
      customerName: S(cust),
      customerPhone: S('09171230001'),
      customerAddress: S(extra.addr ?? 'Seeded address'),
      orderType: S(delivery ? 'delivery' : 'walk_in'),
      productId: S(product.id),
      productName: S(product.name),
      unitPrice: D(product.price),
      quantity: I(qty),
      totalAmount: D(total),
      status: S(status),
      paymentStatus: S(paid),
      contactNumber: S('09171230001'),
      deliveryRequest: S(extra.req ?? ''),
      driverNearby: B(extra.nearby ?? false),
      createdAt: T(when),
      updatedAt: T(when),
    };
  }

  for (let daysAgo = 34; daysAgo >= 1; daysAgo--) {
    const perDay = between(2, 3);
    for (let k = 0; k < perDay; k++) {
      const when = new Date(today.getTime() - (daysAgo * 24 + between(1, 9)) * 3600 * 1000);
      const cust = pick(names);
      const product = pick(products.slice(0, 2));
      const qty = between(1, 3);
      const delivery = rand() > 0.5;
      const method = rand() > 0.5 ? 'cash' : 'gcash';
      const fields = orderFields(cust, product, qty, delivery, when, 'delivered', 'paid', method);
      const total = product.price * qty + (delivery ? 20 : 0);
      const saleFields = {
        amount: D(total),
        type: S(delivery ? 'delivery' : 'walk_in'),
        paymentMethod: S(method),
        recordedByName: S('Miguel Ramos'),
        orderId: NU,
        customerId: S(customerByName[cust]),
        customerName: S(cust),
        productSummary: S(`${product.name} × ${qty}`),
        note: S(''),
        soldAt: T(when),
      };
      orderJobs.push(async () => {
        const o = await authedWrite(TOKEN, 'orders', fields);
        const orderId = o.name.split('/').pop();
        saleFields.orderId = S(orderId);
        await authedWrite(TOKEN, 'sales', saleFields);
      });
      orderCount++;
    }
  }
  for (let i = 0; i < 26; i++) {
    const offH = between(0, 34) * 24 + between(1, 10);
    const when = new Date(today.getTime() - offH * 3600 * 1000);
    if (!Number.isFinite(when.getTime())) {
      console.error('BAD WHEN', JSON.stringify({ i, offH, todayMs: today.getTime() }));
      console.error('between src:', between.toString());
      console.error('rand samples:', [0,1,2,3,4].map(() => rand()).join(', '));
      process.exit(3);
    }
    const amount = between(1, 4) * 40;
    const saleFields = {
      amount: D(amount), type: S('walk_in'),
      paymentMethod: S(rand() > 0.5 ? 'cash' : 'gcash'),
      recordedByName: S('Miguel Ramos'),
      orderId: NU, customerId: NU, customerName: S('Walk-in Customer'),
      productSummary: S('Purified Water (Round 5-gal)'), note: S(''), soldAt: T(when),
    };
    orderJobs.push(() => authedWrite(TOKEN, 'sales', saleFields));
  }
  await chunk(orderJobs, (f) => f(), 8);
  console.log(`   ${orderCount} delivered orders + matching sales + 26 walk-in sales`);

  console.log('8 · Active orders across every status…');
  const p = products[0];
  async function activeOrder(cust, status, ageHours, nearby = false, req = 'Call upon arrival') {
    const when = new Date(today.getTime() - ageHours * 3600 * 1000);
    const res = await authedWrite(TOKEN, 'orders', orderFields(
      cust, p, 2, true, when, status,
      status === 'delivered' ? 'paid' : 'unpaid',
      status === 'delivered' ? 'cash' : '', 
      { addr: cust === 'Maria Santos' ? '12 Rizal St., Brgy. San Isidro' : 'Seeded active address', req, nearby },
    ));
    return res.name.split('/').pop();
  }
  const pendingOrderId = await activeOrder('Juan Dela Cruz', 'pending', 0.4);
  await activeOrder('Grace Lim', 'pending', 1);
  const confirmedOrderId = await activeOrder('Ana Reyes', 'confirmed', 2);
  const preparingOrderId = await activeOrder('Carlo Mendoza', 'preparing', 3);
  const transitOrderId = await activeOrder('Maria Santos', 'in_transit', 4, true);
  await activeOrder('Rico Torres', 'delivered', 6);

  await authedWrite(TOKEN, 'notifications', {
    userId: S(MARIA_UID), orderId: S(transitOrderId), type: S('near_arrival'),
    title: S('Delivery is near'),
    body: S('Your water delivery is arriving at your location in a few minutes.'),
    read: B(false), createdAt: T(now()),
  });

  console.log('9 · Linking gallons to active orders…');
  const plan = [
    ['GLN-0001', 'assigned', pendingOrderId, 'Juan Dela Cruz'],
    ['GLN-0002', 'assigned', pendingOrderId, 'Juan Dela Cruz'],
    ['GLN-0003', 'assigned', confirmedOrderId, 'Ana Reyes'],
    ['GLN-0004', 'assigned', confirmedOrderId, 'Ana Reyes'],
    ['GLN-0005', 'out_for_delivery', preparingOrderId, 'Carlo Mendoza'],
    ['GLN-0006', 'out_for_delivery', preparingOrderId, 'Carlo Mendoza'],
    ['GLN-0007', 'out_for_delivery', transitOrderId, 'Maria Santos'],
    ['GLN-0008', 'out_for_delivery', transitOrderId, 'Maria Santos'],
    ['GLN-0014', 'with_customer', null, 'Rico Torres'],
    ['GLN-0015', 'returned', null, null],
    ['GLN-0016', 'damaged', null, null],
  ];
  await chunk(plan, ([code, status, orderId, cust]) =>
    authedWrite(TOKEN, `gallons/${code}`, {
      gallonId: S(code), qrCodeValue: S(code), status: S(status),
      currentCustomerId: cust ? S(customerByName[cust]) : NU,
      currentCustomerName: cust ? S(cust) : (status === 'with_customer' ? S('Rico Torres') : NU),
      currentOrderId: orderId ? S(orderId) : NU,
      createdAt: T(now()), updatedAt: T(now()),
    }, 'PATCH'), 6);

  console.log('10 · Expenses…');
  const expenseDefs = [
    ['Electricity bill', 'Electricity', 4850, 28],
    ['Water source fee', 'Water Bill', 2100, 27],
    ['Store rent', 'Rent', 8000, 26],
    ['Driver salary', 'Salaries', 5500, 24],
    ['Bottle caps restock', 'Supplies', 750, 20],
    ['Delivery fuel', 'Transportation', 900, 17],
    ['UV lamp replacement', 'Maintenance', 1350, 13],
    ['Diesel top-up', 'Transportation', 600, 9],
    ['Filters & sediment', 'Supplies', 1650, 6],
    ['Electricity bill', 'Electricity', 4620, 3],
    ['Driver salary advance', 'Salaries', 2000, 2],
    ['Truck maintenance', 'Maintenance', 2400, 1],
  ];
  await chunk(expenseDefs, ([title, category, amount, daysAgo]) =>
    authedWrite(TOKEN, 'expenses', {
      title: S(title), category: S(category), amount: D(amount),
      spentAt: T(new Date(today.getTime() - daysAgo * 24 * 3600 * 1000)),
      createdByName: S('Station Administrator'), notes: S(''),
    }), 6);

  console.log('\n✅ PROVISIONING COMPLETE');
  console.log('   admin@aquaph.test / Aqua123!  (Administrator)');
  console.log('   staff@aquaph.test / Aqua123!  (Staff)');
  console.log('   maria@aquaph.test / Aqua123!  (Customer)');
}

main().catch((e) => {
  console.error('\n❌ FAILED:', e.message);
  console.error(e.stack);
  process.exit(1);
});
