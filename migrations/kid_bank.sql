-- 1 up
create table users (
  username text primary key,
  password text,
  name text
);
create table transactions (
  id integer primary key autoincrement,
  username text,
  date datetime,
  tx_with text,
  memo text,
  pennies integer,
  FOREIGN KEY(username) REFERENCES users(username)
);
-- 1 down
drop table users;
drop table transactions;
