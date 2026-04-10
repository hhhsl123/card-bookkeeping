export interface Env {
  DB: D1Database;
  APP_CACHE: KVNamespace;
  CORS_ORIGIN?: string;
}

type CardStatus = 'available' | 'picked' | 'bad' | 'cleared';

interface CardItem {
  id: string;
  label: string;
  secret: string;
  face: number;
  status: CardStatus;
  statusBy: string | null;
  statusAt: number | null;
  actualBalance: number;
  note: string;
  updatedAt: number;
}

interface Batch {
  id: string;
  workspaceId: string;
  name: string;
  rate: number;
  batchDate: string;
  note: string;
  createdAt: number;
  updatedAt: number;
  cleared: boolean;
  clearedAt: number | null;
  cards: CardItem[];
}

interface ActivityLog {
  id: string;
  type: string;
  summary: string;
  actor: string;
  createdAt: number;
  batchId: string | null;
  cardIds: string[];
  meta: Record<string, unknown>;
}

interface AppSnapshot {
  workspaceId: string;
  workspaceName: string;
  persons: string[];
  recentPickAmounts: number[];
  batches: Batch[];
  activities: ActivityLog[];
  updatedAt: number;
}

interface ImportPreview {
  cards: Array<{ label: string; secret: string; face: number; lineNumber: number }>;
  issues: Array<{ lineNumber: number; message: string }>;
  duplicateWithinInput: string[];
  duplicateExisting: Record<string, string>;
  totalLines: number;
}

const json = (env: Env, body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': env.CORS_ORIGIN ?? '*',
      'access-control-allow-headers': 'content-type,x-workspace-id,x-workspace-pin',
      'access-control-allow-methods': 'GET,POST,PUT,OPTIONS',
    },
  });

const now = (): number => Date.now();
const toNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number.parseFloat(value) || 0;
  return 0;
};

const toInt = (value: unknown): number => {
  if (typeof value === 'number') return Math.trunc(value);
  if (typeof value === 'string') return Number.parseInt(value, 10) || 0;
  return 0;
};

const asString = (value: unknown, fallback = ''): string => (value == null ? fallback : String(value));

const asStringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.map((item) => String(item)) : [];

const asNumberArray = (value: unknown): number[] =>
  Array.isArray(value)
    ? value.map((item) => toNumber(item)).filter((item) => item > 0).slice(0, 6)
    : [];

async function sha256(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((item) => item.toString(16).padStart(2, '0'))
    .join('');
}

function normalizeCard(raw: Record<string, unknown>): CardItem {
  const legacySold = raw.sold === true;
  const legacyBad = raw.bad === true;
  const statusValue = legacyBad
    ? 'bad'
    : legacySold
        ? 'picked'
        : (asString(raw.status, 'available') as CardStatus);
  return {
    id: asString(raw.id),
    label: asString(raw.label),
    secret: asString(raw.secret),
    face: toNumber(raw.face),
    status: ['available', 'picked', 'bad', 'cleared'].includes(statusValue) ? statusValue : 'available',
    statusBy: raw.statusBy ? asString(raw.statusBy) : (raw.soldBy ? asString(raw.soldBy) : null),
    statusAt: raw.statusAt != null ? toInt(raw.statusAt) : (raw.soldDate != null ? toInt(raw.soldDate) : null),
    actualBalance: raw.actualBalance != null ? toNumber(raw.actualBalance) : toNumber(raw.soldPrice),
    note: asString(raw.note ?? raw.soldNote),
    updatedAt: raw.updatedAt != null ? toInt(raw.updatedAt) : now(),
  };
}

function normalizeBatch(raw: Record<string, unknown>, workspaceId: string): Batch {
  const cards = Array.isArray(raw.cards)
    ? raw.cards.map((item) => normalizeCard(item as Record<string, unknown>))
    : [];
  return {
    id: asString(raw.id),
    workspaceId,
    name: asString(raw.name),
    rate: toNumber(raw.rate),
    batchDate: asString(raw.batchDate, new Date().toISOString().slice(0, 10)),
    note: asString(raw.note),
    createdAt: raw.createdAt != null ? toInt(raw.createdAt) : (raw.date != null ? toInt(raw.date) : now()),
    updatedAt: raw.updatedAt != null ? toInt(raw.updatedAt) : (raw.date != null ? toInt(raw.date) : now()),
    cleared: raw.cleared === true || raw.deleted === true,
    clearedAt: raw.clearedAt != null ? toInt(raw.clearedAt) : null,
    cards,
  };
}

function normalizeActivity(raw: Record<string, unknown>): ActivityLog {
  return {
    id: asString(raw.id),
    type: asString(raw.type),
    summary: asString(raw.summary),
    actor: asString(raw.actor),
    createdAt: raw.createdAt != null ? toInt(raw.createdAt) : now(),
    batchId: raw.batchId != null ? asString(raw.batchId) : null,
    cardIds: asStringArray(raw.cardIds),
    meta: typeof raw.meta === 'object' && raw.meta !== null ? (raw.meta as Record<string, unknown>) : {},
  };
}

function normalizeSnapshot(raw: Record<string, unknown>, workspaceId: string): AppSnapshot {
  const batches = Array.isArray(raw.batches)
    ? raw.batches.map((item) => normalizeBatch(item as Record<string, unknown>, workspaceId))
    : [];
  const persons = asStringArray(raw.persons);
  return {
    workspaceId,
    workspaceName: asString(raw.workspaceName, 'Card Bookkeeping'),
    persons: persons.length > 0 ? persons : ['星河', '石'],
    recentPickAmounts: asNumberArray(raw.recentPickAmounts),
    batches,
    activities: Array.isArray(raw.activities)
      ? raw.activities.map((item) => normalizeActivity(item as Record<string, unknown>)).slice(0, 100)
      : [],
    updatedAt: raw.updatedAt != null ? toInt(raw.updatedAt) : now(),
  };
}

function exactPick(cards: CardItem[], target: number): CardItem[] | null {
  const sorted = cards
    .filter((card) => card.status === 'available')
    .sort((left, right) => right.face - left.face);
  let best: CardItem[] | null = null;

  const search = (start: number, remaining: number, chosen: CardItem[]): void => {
    if (Math.abs(remaining) < 0.001) {
      if (best == null || chosen.length < best.length) {
        best = [...chosen];
      }
      return;
    }
    if (remaining < -0.001 || start >= sorted.length) return;
    if (best != null && chosen.length >= best.length) return;

    for (let index = start; index < sorted.length; index += 1) {
      const card = sorted[index];
      if (card.face > remaining + 0.001) continue;
      chosen.push(card);
      search(index + 1, remaining - card.face, chosen);
      chosen.pop();
    }
  };

  search(0, target, []);
  return best;
}

function parseImport(raw: string, existingLabels: Map<string, string>, unifiedFace?: number): ImportPreview {
  const preview: ImportPreview = {
    cards: [],
    issues: [],
    duplicateWithinInput: [],
    duplicateExisting: {},
    totalLines: raw.split('\n').length,
  };
  const seenLabels = new Set<string>();
  const override = unifiedFace && unifiedFace > 0 ? unifiedFace : undefined;

  raw.split('\n').forEach((lineRaw, index) => {
    const line = lineRaw.trim();
    if (!line) return;
    const lineNumber = index + 1;
    const parts = line.split(/\s+/).filter(Boolean);
    if (parts.length === 0) return;

    let label = '';
    let secret = '';
    let face = 0;

    if (override) {
      label = parts[0];
      secret = parts.length > 1 ? parts.slice(1).join(' ') : '';
      face = override;
    } else {
      const last = parts[parts.length - 1];
      const parsed = Number.parseFloat(last);
      if (Number.isNaN(parsed)) {
        preview.issues.push({ lineNumber, message: `第 ${lineNumber} 行缺少面值` });
        return;
      }
      face = parsed;
      if (parts.length >= 3) {
        label = parts.slice(0, parts.length - 2).join(' ');
        secret = parts[parts.length - 2];
      } else if (parts.length === 2) {
        label = parts[0];
      } else {
        preview.issues.push({ lineNumber, message: `第 ${lineNumber} 行格式无法识别` });
        return;
      }
    }

    if (!label || face <= 0) {
      preview.issues.push({ lineNumber, message: `第 ${lineNumber} 行内容无效` });
      return;
    }
    if (seenLabels.has(label)) {
      preview.duplicateWithinInput.push(label);
      return;
    }
    seenLabels.add(label);

    const existingBatch = existingLabels.get(label);
    if (existingBatch) {
      preview.duplicateExisting[label] = existingBatch;
      return;
    }

    preview.cards.push({ label, secret, face, lineNumber });
  });

  return preview;
}

function computeSettlement(snapshot: AppSnapshot): Record<string, unknown> {
  const activeBatches = snapshot.batches.filter((batch) => !batch.cleared);
  const archivedBatches = snapshot.batches.filter((batch) => batch.cleared);

  const summarizeBatch = (batch: Batch) => {
    const visibleCards = batch.cards.filter((card) => card.status !== 'cleared');
    const availableCards = visibleCards.filter((card) => card.status === 'available');
    const pickedCards = visibleCards.filter((card) => card.status === 'picked');
    const badCards = visibleCards.filter((card) => card.status === 'bad');
    const revenue = pickedCards.reduce((sum, card) => sum + card.face, 0) + badCards.reduce((sum, card) => sum + card.actualBalance, 0);
    const cost = visibleCards.reduce((sum, card) => sum + (card.face * batch.rate), 0);
    const availableValue = availableCards.reduce((sum, card) => sum + card.face, 0);
    const badRecovered = badCards.reduce((sum, card) => sum + card.actualBalance, 0);
    const badLoss = badCards.reduce((sum, card) => sum + card.face, 0) - badRecovered;
    return {
      batch,
      revenue,
      cost,
      profit: revenue - cost,
      availableValue,
      badRecovered,
      badLoss,
    };
  };

  const batchSummaries = activeBatches.map(summarizeBatch);
  const archivedSummaries = archivedBatches.map(summarizeBatch);
  const personSummaries = snapshot.persons.map((person) => {
    const cards: CardItem[] = [];
    let revenue = 0;
    let cost = 0;
    activeBatches.forEach((batch) => {
      batch.cards.forEach((card) => {
        if (card.status === 'picked' && card.statusBy === person) {
          cards.push(card);
          revenue += card.face;
          cost += card.face * batch.rate;
        }
      });
    });
    return {
      person,
      count: cards.length,
      revenue,
      cost,
      profit: revenue - cost,
      cards,
    };
  });

  const totalRevenue = batchSummaries.reduce((sum, batch) => sum + (batch.revenue as number), 0);
  const totalCost = batchSummaries.reduce((sum, batch) => sum + (batch.cost as number), 0);
  const badRecovered = batchSummaries.reduce((sum, batch) => sum + (batch.badRecovered as number), 0);
  const badLoss = batchSummaries.reduce((sum, batch) => sum + (batch.badLoss as number), 0);
  const availableValue = batchSummaries.reduce((sum, batch) => sum + (batch.availableValue as number), 0);

  return {
    totalRevenue,
    totalCost,
    totalProfit: totalRevenue - totalCost,
    badRecovered,
    badLoss,
    availableValue,
    batches: batchSummaries,
    archivedBatches: archivedSummaries,
    persons: personSummaries,
  };
}

async function getWorkspaceRecord(env: Env, workspaceId: string) {
  return env.DB.prepare('SELECT * FROM workspaces WHERE id = ?')
    .bind(workspaceId)
    .first<{
      id: string;
      name: string;
      persons_json: string;
      recent_pick_amounts_json: string;
      pin_hash: string;
      updated_at: number;
    }>();
}

async function authorize(request: Request, env: Env, workspaceId: string, allowBootstrap = false): Promise<Response | null> {
  const workspace = await getWorkspaceRecord(env, workspaceId);
  if (!workspace) {
    if (allowBootstrap) return null;
    return json(env, { error: 'Workspace not found. Push a snapshot first.' }, 404);
  }

  const pin = request.headers.get('x-workspace-pin') ?? '';
  if (!pin) {
    return json(env, { error: 'Workspace PIN is required.' }, 401);
  }
  const hashed = await sha256(pin);
  if (hashed !== workspace.pin_hash) {
    return json(env, { error: 'Workspace PIN is invalid.' }, 403);
  }
  return null;
}

async function readSnapshot(env: Env, workspaceId: string): Promise<AppSnapshot | null> {
  const workspace = await getWorkspaceRecord(env, workspaceId);
  if (!workspace) return null;

  const batchesResult = await env.DB.prepare('SELECT * FROM batches WHERE workspace_id = ? ORDER BY created_at DESC')
    .bind(workspaceId)
    .all<{
      id: string;
      workspace_id: string;
      name: string;
      rate: number;
      batch_date: string;
      note: string;
      created_at: number;
      updated_at: number;
      cleared: number;
      cleared_at: number | null;
    }>();
  const cardsResult = await env.DB.prepare(
    'SELECT cards.* FROM cards INNER JOIN batches ON batches.id = cards.batch_id WHERE batches.workspace_id = ? ORDER BY cards.updated_at DESC',
  )
    .bind(workspaceId)
    .all<{
      id: string;
      batch_id: string;
      label: string;
      secret: string;
      face: number;
      status: CardStatus;
      status_by: string | null;
      status_at: number | null;
      actual_balance: number;
      note: string;
      updated_at: number;
    }>();
  const activitiesResult = await env.DB.prepare('SELECT * FROM activity_log WHERE workspace_id = ? ORDER BY created_at DESC LIMIT 100')
    .bind(workspaceId)
    .all<{
      id: string;
      workspace_id: string;
      type: string;
      summary: string;
      actor: string;
      created_at: number;
      batch_id: string | null;
      card_ids_json: string;
      meta_json: string;
    }>();

  const cardsByBatch = new Map<string, CardItem[]>();
  for (const row of cardsResult.results) {
    const list = cardsByBatch.get(row.batch_id) ?? [];
    list.push({
      id: row.id,
      label: row.label,
      secret: row.secret,
      face: toNumber(row.face),
      status: row.status,
      statusBy: row.status_by,
      statusAt: row.status_at,
      actualBalance: toNumber(row.actual_balance),
      note: row.note,
      updatedAt: row.updated_at,
    });
    cardsByBatch.set(row.batch_id, list);
  }

  let recentPickAmounts: number[] = [];
  try {
    recentPickAmounts = JSON.parse(workspace.recent_pick_amounts_json) as number[];
  } catch {
    try {
      const cached = await env.APP_CACHE.get(`recent:${workspaceId}`);
      recentPickAmounts = cached ? (JSON.parse(cached) as number[]) : [];
    } catch {
      recentPickAmounts = [];
    }
  }

  return {
    workspaceId,
    workspaceName: workspace.name,
    persons: JSON.parse(workspace.persons_json) as string[],
    recentPickAmounts,
    batches: batchesResult.results.map((row) => ({
      id: row.id,
      workspaceId: row.workspace_id,
      name: row.name,
      rate: toNumber(row.rate),
      batchDate: row.batch_date,
      note: row.note,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      cleared: row.cleared === 1,
      clearedAt: row.cleared_at,
      cards: cardsByBatch.get(row.id) ?? [],
    })),
    activities: activitiesResult.results.map((row) => ({
      id: row.id,
      type: row.type,
      summary: row.summary,
      actor: row.actor,
      createdAt: row.created_at,
      batchId: row.batch_id,
      cardIds: JSON.parse(row.card_ids_json) as string[],
      meta: JSON.parse(row.meta_json) as Record<string, unknown>,
    })),
    updatedAt: workspace.updated_at,
  };
}

async function cacheSettlement(env: Env, snapshot: AppSnapshot): Promise<void> {
  const settlement = computeSettlement(snapshot);
  await env.APP_CACHE.put(`settlement:${snapshot.workspaceId}`, JSON.stringify(settlement), { expirationTtl: 3600 });
  await env.APP_CACHE.put(`recent:${snapshot.workspaceId}`, JSON.stringify(snapshot.recentPickAmounts), { expirationTtl: 3600 });
}

async function writeSnapshot(env: Env, workspaceId: string, pin: string, rawSnapshot: Record<string, unknown>): Promise<AppSnapshot> {
  const snapshot = normalizeSnapshot(rawSnapshot, workspaceId);
  const pinHash = await sha256(pin);
  const statements: D1PreparedStatement[] = [
    env.DB.prepare(
      'INSERT INTO workspaces (id, name, persons_json, recent_pick_amounts_json, pin_hash, updated_at) VALUES (?, ?, ?, ?, ?, ?) ' +
          'ON CONFLICT(id) DO UPDATE SET name = excluded.name, persons_json = excluded.persons_json, recent_pick_amounts_json = excluded.recent_pick_amounts_json, pin_hash = excluded.pin_hash, updated_at = excluded.updated_at',
    ).bind(
      workspaceId,
      snapshot.workspaceName,
      JSON.stringify(snapshot.persons),
      JSON.stringify(snapshot.recentPickAmounts),
      pinHash,
      snapshot.updatedAt || now(),
    ),
    env.DB.prepare('DELETE FROM activity_log WHERE workspace_id = ?').bind(workspaceId),
    env.DB.prepare('DELETE FROM cards WHERE batch_id IN (SELECT id FROM batches WHERE workspace_id = ?)').bind(workspaceId),
    env.DB.prepare('DELETE FROM batches WHERE workspace_id = ?').bind(workspaceId),
  ];

  for (const batch of snapshot.batches) {
    statements.push(
      env.DB.prepare(
        'INSERT INTO batches (id, workspace_id, name, rate, batch_date, note, created_at, updated_at, cleared, cleared_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ).bind(
        batch.id,
        workspaceId,
        batch.name,
        batch.rate,
        batch.batchDate,
        batch.note,
        batch.createdAt,
        batch.updatedAt,
        batch.cleared ? 1 : 0,
        batch.clearedAt,
      ),
    );

    for (const card of batch.cards) {
      statements.push(
        env.DB.prepare(
          'INSERT INTO cards (id, batch_id, label, secret, face, status, status_by, status_at, actual_balance, note, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        ).bind(
          card.id,
          batch.id,
          card.label,
          card.secret,
          card.face,
          card.status,
          card.statusBy,
          card.statusAt,
          card.actualBalance,
          card.note,
          card.updatedAt,
        ),
      );
    }
  }

  for (const activity of snapshot.activities.slice(0, 100)) {
    statements.push(
      env.DB.prepare(
        'INSERT INTO activity_log (id, workspace_id, type, summary, actor, created_at, batch_id, card_ids_json, meta_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ).bind(
        activity.id,
        workspaceId,
        activity.type,
        activity.summary,
        activity.actor,
        activity.createdAt,
        activity.batchId,
        JSON.stringify(activity.cardIds),
        JSON.stringify(activity.meta),
      ),
    );
  }

  await env.DB.batch(statements);
  const fresh = await readSnapshot(env, workspaceId);
  if (!fresh) {
    throw new Error('Failed to re-read snapshot after write.');
  }
  await cacheSettlement(env, fresh);
  return fresh;
}

function buildExistingLabelMap(snapshot: AppSnapshot): Map<string, string> {
  const labels = new Map<string, string>();
  snapshot.batches
    .filter((batch) => !batch.cleared)
    .forEach((batch) => {
      batch.cards
        .filter((card) => card.status !== 'cleared')
        .forEach((card) => labels.set(card.label, batch.name));
    });
  return labels;
}

function createId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

async function parseBody(request: Request): Promise<Record<string, unknown>> {
  const jsonBody = await request.json().catch(() => ({}));
  return typeof jsonBody === 'object' && jsonBody !== null ? (jsonBody as Record<string, unknown>) : {};
}

async function handleImportPreview(request: Request, env: Env, workspaceId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  const existing = snapshot ? buildExistingLabelMap(snapshot) : new Map<string, string>();
  const preview = parseImport(asString(body.raw), existing, body.unifiedFace != null ? toNumber(body.unifiedFace) : undefined);
  return json(env, { data: preview });
}

async function handleCreateBatch(request: Request, env: Env, workspaceId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = (await readSnapshot(env, workspaceId)) ?? normalizeSnapshot({}, workspaceId);
  const sourceCards = Array.isArray(body.cards)
    ? body.cards.map((item) => normalizeCard(item as Record<string, unknown>))
    : [];
  const timestamp = now();
  const batchId = asString(body.id, createId('batch'));
  const preparedCards = sourceCards.map((card) => ({
    ...card,
    id: card.id || createId('card'),
    status: 'available' as const,
    statusBy: null,
    statusAt: null,
    actualBalance: 0,
    updatedAt: timestamp,
  }));
  snapshot.batches.unshift({
    id: batchId,
    workspaceId,
    name: asString(body.name),
    rate: toNumber(body.rate),
    batchDate: asString(body.batchDate, new Date().toISOString().slice(0, 10)),
    note: asString(body.note),
    createdAt: timestamp,
    updatedAt: timestamp,
    cleared: false,
    clearedAt: null,
    cards: preparedCards,
  });
  snapshot.updatedAt = timestamp;
  snapshot.activities.unshift({
    id: createId('activity'),
    type: 'import',
    summary: `创建批次 ${asString(body.name)}，导入 ${preparedCards.length} 张卡`,
    actor: asString(body.actor, '系统'),
    createdAt: timestamp,
    batchId,
    cardIds: preparedCards.map((card) => card.id),
    meta: {},
  });
  const pin = request.headers.get('x-workspace-pin') ?? '';
  const saved = await writeSnapshot(env, workspaceId, pin, snapshot as unknown as Record<string, unknown>);
  return json(env, { data: saved });
}

async function handleAppendCards(request: Request, env: Env, workspaceId: string, batchId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const batch = snapshot.batches.find((item) => item.id == batchId);
  if (!batch) return json(env, { error: 'Batch not found.' }, 404);
  const timestamp = now();
  const sourceCards = Array.isArray(body.cards)
    ? body.cards.map((item) => normalizeCard(item as Record<string, unknown>))
    : [];
  const preparedCards = sourceCards.map((card) => ({
    ...card,
    id: card.id || createId('card'),
    status: 'available' as const,
    statusBy: null,
    statusAt: null,
    actualBalance: 0,
    updatedAt: timestamp,
  }));
  batch.cards.push(
    ...preparedCards,
  );
  batch.updatedAt = timestamp;
  snapshot.updatedAt = timestamp;
  snapshot.activities.unshift({
    id: createId('activity'),
    type: 'import',
    summary: `向 ${batch.name} 追加 ${preparedCards.length} 张卡`,
    actor: asString(body.actor, '系统'),
    createdAt: timestamp,
    batchId,
    cardIds: preparedCards.map((card) => card.id),
    meta: {},
  });
  const pin = request.headers.get('x-workspace-pin') ?? '';
  const saved = await writeSnapshot(env, workspaceId, pin, snapshot as unknown as Record<string, unknown>);
  return json(env, { data: saved });
}

async function handlePickSuggest(request: Request, env: Env, workspaceId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const batch = snapshot.batches.find((item) => item.id === asString(body.batchId));
  if (!batch) return json(env, { error: 'Batch not found.' }, 404);
  const result = exactPick(batch.cards, toNumber(body.target));
  return json(env, { data: { cards: result ?? [] } });
}

async function handlePickConfirm(request: Request, env: Env, workspaceId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const batch = snapshot.batches.find((item) => item.id === asString(body.batchId));
  if (!batch) return json(env, { error: 'Batch not found.' }, 404);
  const ids = new Set(asStringArray(body.cardIds));
  const actor = asString(body.actor, '未知');
  const target = toNumber(body.target);
  const timestamp = now();
  batch.cards.forEach((card) => {
    if (ids.has(card.id)) {
      card.status = 'picked';
      card.statusBy = actor;
      card.statusAt = timestamp;
      card.actualBalance = 0;
      card.updatedAt = timestamp;
    }
  });
  batch.updatedAt = timestamp;
  snapshot.recentPickAmounts = [target, ...snapshot.recentPickAmounts.filter((item) => Math.abs(item - target) > 0.001)]
    .filter((item) => item > 0)
    .slice(0, 6);
  snapshot.updatedAt = timestamp;
  snapshot.activities.unshift({
    id: createId('activity'),
    type: 'pick',
    summary: `提卡 ${ids.size} 张，金额 ${target}`,
    actor,
    createdAt: timestamp,
    batchId: batch.id,
    cardIds: [...ids],
    meta: { target },
  });
  const pin = request.headers.get('x-workspace-pin') ?? '';
  const saved = await writeSnapshot(env, workspaceId, pin, snapshot as unknown as Record<string, unknown>);
  return json(env, { data: saved });
}

async function handleCardStatus(request: Request, env: Env, workspaceId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const batch = snapshot.batches.find((item) => item.id === asString(body.batchId));
  if (!batch) return json(env, { error: 'Batch not found.' }, 404);
  const ids = new Set(asStringArray(body.cardIds));
  const status = asString(body.status, 'available') as CardStatus;
  const actor = asString(body.actor, '未知');
  const actualBalance = toNumber(body.actualBalance);
  const timestamp = now();
  batch.cards.forEach((card) => {
    if (ids.has(card.id)) {
      card.status = status;
      card.statusBy = actor;
      card.statusAt = timestamp;
      card.actualBalance = status === 'bad' ? actualBalance : 0;
      card.updatedAt = timestamp;
    }
  });
  batch.updatedAt = timestamp;
  snapshot.updatedAt = timestamp;
  snapshot.activities.unshift({
    id: createId('activity'),
    type: 'card_status',
    summary: `更新 ${ids.size} 张卡状态为 ${status}`,
    actor,
    createdAt: timestamp,
    batchId: batch.id,
    cardIds: [...ids],
    meta: { status, actualBalance },
  });
  const pin = request.headers.get('x-workspace-pin') ?? '';
  const saved = await writeSnapshot(env, workspaceId, pin, snapshot as unknown as Record<string, unknown>);
  return json(env, { data: saved });
}

async function handleClearBatch(request: Request, env: Env, workspaceId: string, batchId: string): Promise<Response> {
  const body = await parseBody(request);
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const batch = snapshot.batches.find((item) => item.id === batchId);
  if (!batch) return json(env, { error: 'Batch not found.' }, 404);
  const timestamp = now();
  batch.cleared = true;
  batch.clearedAt = timestamp;
  batch.updatedAt = timestamp;
  batch.cards.forEach((card) => {
    card.status = 'cleared';
    card.statusAt = timestamp;
    card.updatedAt = timestamp;
  });
  snapshot.updatedAt = timestamp;
  snapshot.activities.unshift({
    id: createId('activity'),
    type: 'clear_batch',
    summary: `清账批次 ${batch.name}`,
    actor: asString(body.actor, '系统'),
    createdAt: timestamp,
    batchId,
    cardIds: [],
    meta: {},
  });
  const pin = request.headers.get('x-workspace-pin') ?? '';
  const saved = await writeSnapshot(env, workspaceId, pin, snapshot as unknown as Record<string, unknown>);
  return json(env, { data: saved });
}

async function handleSettlements(env: Env, workspaceId: string): Promise<Response> {
  const cached = await env.APP_CACHE.get(`settlement:${workspaceId}`);
  if (cached) {
    return json(env, { data: JSON.parse(cached) });
  }
  const snapshot = await readSnapshot(env, workspaceId);
  if (!snapshot) return json(env, { error: 'Workspace not found.' }, 404);
  const settlement = computeSettlement(snapshot);
  await env.APP_CACHE.put(`settlement:${workspaceId}`, JSON.stringify(settlement), { expirationTtl: 3600 });
  return json(env, { data: settlement });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return json(env, { ok: true });
    }

    const url = new URL(request.url);
    const workspaceId = request.headers.get('x-workspace-id') ?? 'default';

    if (url.pathname === '/api/health') {
      return json(env, { ok: true, now: now() });
    }

    if (url.pathname.startsWith('/api/')) {
      const authResponse = await authorize(
        request,
        env,
        workspaceId,
        request.method === 'PUT' && url.pathname === '/api/workspace/snapshot',
      );
      if (authResponse) return authResponse;
    }

    if (url.pathname === '/api/batches' && request.method === 'GET') {
      const snapshot = await readSnapshot(env, workspaceId);
      return snapshot ? json(env, { data: snapshot }) : json(env, { error: 'Workspace not found.' }, 404);
    }

    if (url.pathname === '/api/workspace/snapshot' && request.method === 'PUT') {
      const body = await parseBody(request);
      const pin = request.headers.get('x-workspace-pin') ?? '';
      if (!pin) return json(env, { error: 'Workspace PIN is required.' }, 401);
      const saved = await writeSnapshot(env, workspaceId, pin, body);
      return json(env, { data: saved });
    }

    if (url.pathname === '/api/import/preview' && request.method === 'POST') {
      return handleImportPreview(request, env, workspaceId);
    }

    if (url.pathname === '/api/batches' && request.method === 'POST') {
      return handleCreateBatch(request, env, workspaceId);
    }

    if (url.pathname.match(/^\/api\/batches\/[^/]+\/cards$/) && request.method === 'POST') {
      const batchId = url.pathname.split('/')[3];
      return handleAppendCards(request, env, workspaceId, batchId);
    }

    if (url.pathname === '/api/picks/suggest' && request.method === 'POST') {
      return handlePickSuggest(request, env, workspaceId);
    }

    if (url.pathname === '/api/picks/confirm' && request.method === 'POST') {
      return handlePickConfirm(request, env, workspaceId);
    }

    if (url.pathname === '/api/cards/status' && request.method === 'POST') {
      return handleCardStatus(request, env, workspaceId);
    }

    if (url.pathname === '/api/settlements/overview' && request.method === 'GET') {
      return handleSettlements(env, workspaceId);
    }

    if (url.pathname.match(/^\/api\/batches\/[^/]+\/clear$/) && request.method === 'POST') {
      const batchId = url.pathname.split('/')[3];
      return handleClearBatch(request, env, workspaceId, batchId);
    }

    return json(env, { error: 'Not found.' }, 404);
  },
};
