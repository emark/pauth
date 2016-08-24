drop database if exists pauth;
create database pauth default character set utf8 collate utf8_bin;
use pauth;
create table clients (id integer primary key auto_increment, cdate datetime, phone varchar(10), ip varchar(15), mac varchar(17) default 0, code integer, token varchar(30));
create table notify_q(id integer primary key auto_increment, token text, result text);
create table rules_q (id integer primary key auto_increment, token text, result int default 0);
create table hosts (id integer primary key auto_increment,cdate datetime,phone varchar(10),ip varchar(15), mac varchar(17));
grant all on pauth.* to pauth@localhost identified by 'awake247';
