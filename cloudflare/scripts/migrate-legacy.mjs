import fs from 'node:fs';

const args = process.argv.slice(2);
const getArg = (name) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
};

const sourcePath = getArg('--source');
const apiBase = getArg('--api-base');
const workspaceId = getArg('--workspace-id') ?? 'default';
const workspacePin = getArg('--workspace-pin');

if (!sourcePath || !apiBase || !workspacePin) {
  console.error('Usage: node scripts/migrate-legacy.mjs --source ./data.json --api-base https://worker.example.workers.dev --workspace-pin 123456 [--workspace-id default]');
  process.exit(1);
}

const raw = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

const snapshot = {
  workspaceId,
  workspaceName: 'Card Bookkeeping',
  persons: Array.isArray(raw.persons) && raw.persons.length > 0 ? raw.persons.map(String) : ['星河', '石'],
  recentPickAmounts: [],
  updatedAt: Date.now(),
  activities: [],
  batches: (Array.isArray(raw.batches) ? raw.batches : []).map((batch) => ({
    id: String(batch.id ?? `batch_${Date.now()}`),
    workspaceId,
    name: String(batch.name ?? ''),
    rate: Number(batch.rate ?? 0),
    batchDate: String(batch.batchDate ?? new Date().toISOString().slice(0, 10)),
    note: '',
    createdAt: Number(batch.date ?? Date.now()),
    updatedAt: Number(batch.date ?? Date.now()),
    cleared: false,
    clearedAt: null,
    cards: (Array.isArray(batch.cards) ? batch.cards : []).map((card) => ({
      id: String(card.id ?? `card_${Date.now()}`),
      label: String(card.label ?? ''),
      secret: String(card.secret ?? ''),
      face: Number(card.face ?? 0),
      status: card.bad ? 'bad' : card.sold ? 'picked' : 'available',
      statusBy: card.soldBy ? String(card.soldBy) : null,
      statusAt: card.soldDate ? Number(card.soldDate) : null,
      actualBalance: Number(card.soldPrice ?? 0),
      note: String(card.soldNote ?? ''),
      updatedAt: Number(card.updatedAt ?? Date.now()),
    })),
  })),
};

const response = await fetch(new URL('/api/workspace/snapshot', apiBase), {
  method: 'PUT',
  headers: {
    'content-type': 'application/json',
    'x-workspace-id': workspaceId,
    'x-workspace-pin': workspacePin,
  },
  body: JSON.stringify(snapshot),
});

if (!response.ok) {
  console.error(await response.text());
  process.exit(1);
}

const result = await response.json();
console.log(JSON.stringify({
  workspaceId,
  batches: snapshot.batches.length,
  cards: snapshot.batches.reduce((sum, batch) => sum + batch.cards.length, 0),
  result,
}, null, 2));
