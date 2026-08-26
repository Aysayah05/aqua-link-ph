const BASE = 'https://firestore.googleapis.com/v1/projects/aqua-link-ph/databases/(default)/documents';
const OWNER = process.env.FB_OWNER_TOKEN;
const H = { Authorization: `Bearer ${OWNER}`, 'Content-Type': 'application/json' };

async function list(coll) {
  const out = [];
  let page = '';
  for (;;) {
    const r = await fetch(`${BASE}/${coll}?pageSize=300${page ? `&pageToken=${page}` : ''}`, { headers: H });
    const j = await r.json();
    for (const d of j.documents ?? []) {
      const path = d.name.split('/documents/')[1];
      if (path) out.push({ path, fields: d.fields ?? {} });
    }
    if (!j.nextPageToken) return out;
    page = j.nextPageToken;
  }
}
async function del(path) {
  const r = await fetch(`${BASE}/${path}`, { method: 'DELETE', headers: H });
  if (!r.ok) throw new Error(`delete ${path}: ${await r.text()}`);
}

const canonical = [
  'Purified Water (Round 5-gal)',
  'Distilled Water (Round 5-gal)',
  'Alkaline Water (Round 5-gal)',
  'Empty Round Containers',
  'Bottle Caps & Seals',
];

const inventory = await list('inventory');
const orders = await list('orders');
const referenced = new Set(
  orders.map((o) => o.fields.productId?.stringValue).filter(Boolean),
);

const byName = new Map();
for (const item of inventory) {
  const name = item.fields.name?.stringValue ?? '';
  if (!byName.has(name)) byName.set(name, []);
  byName.get(name).push(item);
}

let kept = 0, deleted = 0;
for (const [name, docs] of byName) {
  const preferred =
    docs.find((d) => referenced.has(d.path.split('/').pop())) ?? docs[0];
  kept++;
  console.log(`keep: ${name} (${preferred.path.split('/').pop()})`);
  for (const d of docs) {
    if (d !== preferred) {
      await del(d.path);
      deleted++;
    }
  }
}
for (const [name] of byName) {
  if (!canonical.includes(name)) console.log(`note: non-canonical item kept — ${name}`);
}

const customers = await list('customers');
const registered = customers.filter((c) => c.fields.userId?.stringValue);
const walkins = customers.filter((c) => !c.fields.userId?.stringValue);
const seen = new Set();
let cDeleted = 0;
for (const c of walkins) {
  const name = c.fields.fullName?.stringValue ?? '';
  if (seen.has(name)) {
    await del(c.path);
    cDeleted++;
  } else {
    seen.add(name);
  }
}
console.log(`\ncustomers: kept ${registered.length} registered + ${seen.size} walk-ins, deleted ${cDeleted} duplicates`);
console.log(`inventory: kept ${kept}, deleted ${deleted}`);
console.log('DONE');
