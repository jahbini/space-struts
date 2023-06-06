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
  console.log("ready to select from email:", email);
  var result = await db.get(`SELECT * FROM users WHERE email = ?`, email);
  console.log("result=", result);
  if (undefined === result || !result.password) {
    return null;
  }
  console.log("again! result=", result);
  let match = await bcrypt.compare(password, result.password);
  //console.log("LOGIN",email,password," Match=",match);
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
  console.log("result of all articles",result);
  return result;
}

export async function getArticlesBytag(params){
  const db = await getDatabase();
  const result = await db.get(`SELECT * FROM articles WHERE COLUMN tag LIKE %?% `,params.tag);
  return result;
}


export async function putArticleById({ id, headline, tags, text,summary,published }) {
  const db = await getDatabase();
console.log("putting article?",id,headline);
   
  return await db.run(
    "UPDATE articles SET headline=(?), tags=(?), summary=(?), text=(?),published=(?) WHERE id =(?)",
    [headline, tags, summary, text, published,id]
	);
}

export async function getArticleById({ id, headline, tags, text,summary,published }) {
  const db = await getDatabase();
console.log("getting article?",id,headline);
  if (id && id != "new"  ) {
	  let result = await db.get(`SELECT * FROM articles WHERE id = ?`, id);
	  console.log("account from ID returning ", result);
	  if (result) return result;
   }
  // if no id we will create a new one. 
  const result = await db.run(
    'INSERT INTO articles (headline,tags,text,summary,published) VALUES (?, ?, ?, ?, ?)',
    [  headline, tags, text, summary, published ]
  );
  result.lastID;
  console.log("we got a result from the article DB");
  return await db.get(`SELECT * FROM articles WHERE id = ?`, result.lastID);
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

//export async function setImage({ stuff}) {
export async function setImage({ photoURL, headline, tags, photoDescription }) {
  const db = await getDatabase();
  sqlite3.verbose();
  console.log("image from form", photoURL, headline, tags, photoDescription);

  db.on("trace", (data) => {
    console.log("SQL PROB", JSON.stringify(data));
  });

  const result = await db.run(
    "UPDATE images SET headline=(?), tags=(?), photoDescription=(?) WHERE photoURL =(?)",
    [headline, tags, photoDescription, photoURL]
  );
  console.log("SQL result", result);
  return result;
}
