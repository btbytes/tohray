CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fullname TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS post (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    author_id INTEGER NOT NULL DEFAULT 1,
    created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    slug varchar(20) NOT NULL DEFAULT (printf('%d', CAST((julianday('now') - 2440587.5) * 86400 AS INTEGER))) UNIQUE,
    content TEXT NOT NULL
);

-- Create a virtual table for full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS post_fts USING fts5(content, content='post', content_rowid='id');

-- Create triggers to keep the FTS index up to date
CREATE TRIGGER IF NOT EXISTS post_ai AFTER INSERT ON post BEGIN
  INSERT INTO post_fts(rowid, content) VALUES (new.id, new.content);
END;

CREATE TRIGGER IF NOT EXISTS post_ad AFTER DELETE ON post BEGIN
  INSERT INTO post_fts(post_fts, rowid, content) VALUES('delete', old.id, old.content);
END;

CREATE TRIGGER IF NOT EXISTS post_au AFTER UPDATE ON post BEGIN
  INSERT INTO post_fts(post_fts, rowid, content) VALUES('delete', old.id, old.content);
  INSERT INTO post_fts(rowid, content) VALUES (new.id, new.content);
END;
