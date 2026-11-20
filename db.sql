-- Applied by review.sh on every run; safe to re-run.
CREATE DATABASE IF NOT EXISTS pr_autoreview CHARACTER SET utf8mb4;
USE pr_autoreview;

-- One row per PR state change; `data` is the event the dashboard renders.
CREATE TABLE IF NOT EXISTS events (
  id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  data   JSON NOT NULL,
  time   VARCHAR(20)  AS (data->>'$.time')   STORED,
  status VARCHAR(20)  AS (data->>'$.status') STORED,
  repo   VARCHAR(200) AS (data->>'$.repo')   STORED,
  number INT          AS (data->'$.number')  STORED,
  sha    CHAR(40)     AS (data->>'$.sha')    STORED,
  INDEX (repo, number)
);

-- owner/repo#N@sha@requested_at keys that were reviewed or failed.
CREATE TABLE IF NOT EXISTS reviewed (pr_key VARCHAR(400) PRIMARY KEY);
CREATE TABLE IF NOT EXISTS failures (pr_key VARCHAR(400) PRIMARY KEY, attempts INT NOT NULL);
