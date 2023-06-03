----------------------------
-- Up
----------------------------
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin INTEGER DEFAULT 0,
  username VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
);

----------------------------
-- Down
----------------------------
DROP TABLE users;
