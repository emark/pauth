create database pauth;
use pauth;
create table clients (id integer primary key auto_increment, cdate datetime, phone varchar(10), ip varchar(15), mac varchar(17), code integer, token varchar(30));
create table notify_q(id integer primary key auto_increment, token text, result text);
create table rules_q (id integer primary key auto_increment, cid integer, result text);
create table hosts (id integer primary key auto_increment,cdate datetime,phone varchar(10),ip varchar(15), mac varchar(17));
