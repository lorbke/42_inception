CREATE DATABASE IF NOT EXISTS wordpress_db;
USE wordpress_db;

CREATE TABLE example (
	id INT AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(255),
	value INT
);

INSERT INTO example (name, value) VALUES ('Sample Name', 123);