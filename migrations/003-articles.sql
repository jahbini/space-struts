----------------------------
-- Up
----------------------------
CREATE TABLE articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  published BOOLEAN,
  headline VARCHAR(255),
  tags VARCHAR(255),
  summary VARCHAR(512),
  text VARCHAR
);

CREATE TABLE articleTags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idTag  VARCHAR(64) NOT NULL,
  idArticle INTEGER  NOT NULL
);

----------------------------
-- Down
----------------------------
DROP TABLE articleTags;
DROP TABLE articles;
