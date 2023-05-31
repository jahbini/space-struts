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
  const result = await db.get(`SELECT * FROM users WHERE email = ?`, email);
  //console.log("result=",result);
  let match = await bcrypt.compare(password, result.password);
  //console.log("LOGIN",email,password," Match=",match);
  delete result.password;
  return result;
}

export async function getUserById(id) {
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM users WHERE id = ?`, id);
  delete result.password;
  return result;
}

export async function getImageByURL(params) {
  console.log("in db getImage", params);
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM images WHERE photoURL = ?`, params.imageurl);
  console.log("image returning ", result);
  if (result) return result;
  console.log("in db inserting getImage", params.imageurl);
  const result2 = await db.run(
    `INSERT INTO images (photoURL,headline,tags) VALUES (?, ?, ?)`,
    params.imageurl,
    "empty Headline",
    "space-struts"
  );
  console.log("creating ", result2);
  return result2;
}

export async function setImage({ id, photoURL, headline, tags, photoDescription }) {
  const db = await getDatabase();
  const result = await db.run(
    `INSERT INTO images WHERE photoURL=? VALUES (?, ?, ?)`,
    photoUrl,
    headline,
    tags,
    photoDescription
  );
  return result;
}
