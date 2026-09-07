ALTER TABLE `qbmultijob_jobs`
    ADD COLUMN IF NOT EXISTS `name` VARCHAR(128) NOT NULL DEFAULT 'unknown' AFTER `citizenid`;

UPDATE `qbmultijob_jobs` m
JOIN `players` p ON p.`citizenid` = m.`citizenid`
SET m.`name` = p.`name`
WHERE m.`name` = 'unknown' AND p.`name` IS NOT NULL;
