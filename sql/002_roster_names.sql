ALTER TABLE `qbmultijob_jobs`
    ADD COLUMN IF NOT EXISTS `name` VARCHAR(128) NOT NULL DEFAULT 'unknown' AFTER `citizenid`;
