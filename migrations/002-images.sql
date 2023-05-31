----------------------------
-- Up
----------------------------
CREATE TABLE images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  headline VARCHAR(255),
  tags VARCHAR(255),
  photoDecription VARCHAR(255),
  photoURL VARCHAR(255) NOT NULL
);

CREATE TABLE imageTags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idTag  VARCHAR(64) NOT NULL,
  idImage INTEGER  NOT NULL
);

CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tag VARCHAR(64) UNIQUE NOT NULL,
  quality INTEGER
)

----------------------------
-- Down
----------------------------
DROP TABLE images;
DROP TABLE imageTags;
DROP TABLE tags;
