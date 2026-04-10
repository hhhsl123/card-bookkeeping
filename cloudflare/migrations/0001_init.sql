CREATE TABLE IF NOT EXISTS workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  persons_json TEXT NOT NULL,
  recent_pick_amounts_json TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS batches (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  name TEXT NOT NULL,
  rate REAL NOT NULL,
  batch_date TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  cleared INTEGER NOT NULL DEFAULT 0,
  cleared_at INTEGER,
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  batch_id TEXT NOT NULL,
  label TEXT NOT NULL,
  secret TEXT NOT NULL DEFAULT '',
  face REAL NOT NULL,
  status TEXT NOT NULL,
  status_by TEXT,
  status_at INTEGER,
  actual_balance REAL NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (batch_id) REFERENCES batches(id)
);

CREATE TABLE IF NOT EXISTS activity_log (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  type TEXT NOT NULL,
  summary TEXT NOT NULL,
  actor TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  batch_id TEXT,
  card_ids_json TEXT NOT NULL,
  meta_json TEXT NOT NULL,
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE INDEX IF NOT EXISTS idx_batches_workspace_id ON batches(workspace_id);
CREATE INDEX IF NOT EXISTS idx_cards_batch_id ON cards(batch_id);
CREATE INDEX IF NOT EXISTS idx_cards_label ON cards(label);
CREATE INDEX IF NOT EXISTS idx_activity_workspace_id ON activity_log(workspace_id);
