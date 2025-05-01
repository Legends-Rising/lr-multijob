CREATE TABLE IF NOT EXISTS `player_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` INT NOT NULL,
  `job` VARCHAR(50) NOT NULL,     
  `grade` INT NOT NULL DEFAULT 0, 
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid_job` (`citizenid`, `job`)
);