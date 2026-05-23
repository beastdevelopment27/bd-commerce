CREATE TABLE IF NOT EXISTS `bd_commerce_claims` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `recipient_identifier` VARCHAR(80) NOT NULL,
  `claim_type` VARCHAR(32) NOT NULL,
  `inventory_item` VARCHAR(100) NOT NULL,
  `quantity` INT NOT NULL,
  `product_name` VARCHAR(100) NOT NULL DEFAULT '',
  `sale_id` INT NULL DEFAULT NULL,
  `source_note` VARCHAR(255) NOT NULL DEFAULT '',
  `claimed_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_claims_recipient_pending` (`recipient_identifier`, `claimed_at`),
  KEY `idx_claims_sale` (`sale_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
