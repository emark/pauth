create database pauth;
use pauth;
create table clients (id integer primary key auto_increment, cdate datetime, phone varchar(10), ip varchar(15), mac varchar(17), code integer);
create table notify_q(id integer primary key auto_increment, cid integer, result text);

