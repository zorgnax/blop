create table posts (
    postid int unsigned primary key auto_increment,
    title varchar(128) not null,
    url varchar(128) unique,
    added datetime,
    published datetime,
    categoryid int unsigned not null,
    content text not null,
    key(published));

create table categories (
    categoryid int unsigned primary key auto_increment,
    name varchar(128) not null unique,
    url varchar(128) unique,
    special varchar(128) unique);

create table tags (
    tagid int unsigned primary key auto_increment,
    postid int unsigned not null,
    name varchar(128) not null,
    unique (postid, name));

create table pages (
    pageid int unsigned primary key auto_increment,
    title varchar(128),
    url varchar(128) unique,
    added datetime,
    published datetime,
    content text,
    sequence float not null,
    parentid int unsigned not null,
    hidden int unsigned not null,
    noheading int unsigned not null,
    key(published));

create table comments (
    commentid int unsigned primary key auto_increment,
    postid int unsigned,
    pageid int unsigned,
    name varchar(128),
    email varchar(128),
    ipaddr varchar(16),
    cookie varchar(32),
    added datetime,
    edited datetime,
    status enum("Pending", "Approved", "Spam"),
    content text);

create table sessions (
    sessionid varchar(32) not null primary key,
    admin int unsigned,
    ipaddr varchar(16),
    added datetime,
    csrf varchar(32) not null);

create table config (
    name varchar(64) not null primary key,
    value text);

create table log (
    logid int unsigned primary key auto_increment,
    date datetime not null,
    ipaddr varchar(16),
    uri varchar(128),
    content text,
    postid int unsigned,
    pageid int unsigned,
    categoryid int unsigned);

create table visits (
    visitid int unsigned primary key auto_increment,
    date datetime not null,
    url varchar(256),
    host varchar(256),
    path varchar(256),
    entrance int unsigned not null,
    ipaddr varchar(16),
    first int unsigned not null,
    agent varchar(256),
    referer varchar(256),
    referer_host varchar(256),
    country varchar(2),
    region varchar(256),
    city varchar(256),
    zip varchar(16),
    area varchar(16),
    latitude double,
    longitude double,
    isp varchar(256),
    key(date),
    key(ipaddr),
    key(first),
    key(entrance, referer),
    key(country),
    key(region),
    key(city)
);

