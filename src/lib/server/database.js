import { open } from "sqlite";
import sqlite3 from "sqlite3";
import path from "path";
import bcrypt from "bcrypt";

let database = null;
/**
 *
 * @returns {Promise<import('sqlite').Database>}
 */
export async function getDatabase() {
  if (!database) {
    database = await open({
      filename: path.join(process.cwd(), "database.db"),
      driver: sqlite3.Database
    });
  }
  return database;
}

export async function createUser({ username, password, email }) {
  const db = await getDatabase();
  const encryptedPassword = await bcrypt.hash(password, 10);
  const result = await db.run(
    `INSERT INTO users (username, password, email) VALUES (?, ?, ?)`,
    username,
    encryptedPassword,
    email
  );
  return result.lastID;
}

export async function loginUser({ email, password }) {
  const db = await getDatabase();
  var result = await db.get(`SELECT * FROM users WHERE email = ?`, email);
  if (undefined === result || !result.password) {
    return null;
  }
  let match = await bcrypt.compare(password, result.password);
  delete result.password;
  return result;
}

export async function getUserById(id) {
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM users WHERE id = ?`, id);
  if (!result) {
    return null;
  }
  delete result.password;
  return result;
}

export async function getAllArticleIdAndHeadline(){
 //no params yet
  const db = await getDatabase();
  const result = await db.all(`SELECT id, headline  FROM articles`);
  return result;
}

export async function getArticlesBytag(params){
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM articles WHERE COLUMN tag LIKE %?% `,params.tag);
  return result;
}


export async function putArticleById({ id, headline, tags, text,summary,published }) {
  const db = await getDatabase();
   
  return await db.run(
    "UPDATE articles SET headline=(?), tags=(?), summary=(?), text=(?),published=(?) WHERE id =(?)",
    [headline, tags, summary, text, published,id]
	);
}

export async function getArticleById({ id, headline, tags, text,summary,published }) {
  const db = await getDatabase();
  if (id && id != "new"  ) {
	  let result = await db.get(`SELECT * FROM articles WHERE id = ?`, id);
	  if (result) return result;
   }
  // if no id we will create a new one. 
  const result = await db.run(
    'INSERT INTO articles (headline,tags,text,summary,published) VALUES (?, ?, ?, ?, ?)',
    [  headline, tags, text, summary, published ]
  );
  result.lastID;
  return await db.get(`SELECT * FROM articles WHERE id = ?`, result.lastID);
}

export async function getImageByURL(params) {
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM images WHERE photoURL = ?`, params.imageurl);
  if (result) return result;
  const result2 = await db.run(
    `INSERT INTO images (photoURL,headline,tags) VALUES (?, ?, ?)`,
    params.imageurl,
    "empty Headline",
    "space-struts"
  );
  return result2;
}

//export async function setImage({ stuff}) {
export async function setImage({ photoURL, headline, tags, photoDescription }) {
  const db = await getDatabase();
  sqlite3.verbose();

  db.on("trace", (data) => {
    console.log("SQL PROB", JSON.stringify(data));
  });

  const result = await db.run(
    "UPDATE images SET headline=(?), tags=(?), photoDescription=(?) WHERE photoURL =(?)",
    [headline, tags, photoDescription, photoURL]
  );
  return result;
}
