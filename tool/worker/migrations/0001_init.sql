CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  provider TEXT NOT NULL,
  provider_sub TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  UNIQUE(provider, provider_sub)
);

CREATE TABLE IF NOT EXISTS records (
  user_id TEXT NOT NULL,
  collection TEXT NOT NULL,
  id TEXT NOT NULL,
  data TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, collection, id)
);

CREATE INDEX IF NOT EXISTS idx_records_since
  ON records (user_id, updated_at_ms);

CREATE TABLE IF NOT EXISTS blob_meta (
  user_id TEXT NOT NULL,
  id TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  size_bytes INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX IF NOT EXISTS idx_blobs_since
  ON blob_meta (user_id, updated_at_ms);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions (user_id);
