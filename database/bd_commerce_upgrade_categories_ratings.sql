CREATE TABLE IF NOT EXISTS `bd_commerce_sales` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `product_name` VARCHAR(100) NOT NULL,
  `description` TEXT NOT NULL,
  `inventory_item` VARCHAR(100) NOT NULL,
  `player_target` VARCHAR(80) NOT NULL DEFAULT '',
  `job_target` VARCHAR(80) NOT NULL DEFAULT '',
  `quantity` INT NOT NULL,
  `price` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `discount` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `sale_type` VARCHAR(16) NOT NULL,
  `category` VARCHAR(32) NOT NULL DEFAULT 'misc',
  `starting_price` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `current_highest_bid` DECIMAL(10,2) NULL DEFAULT NULL,
  `highest_bidder` VARCHAR(80) NOT NULL DEFAULT '',
  `auction_end_time` TIMESTAMP NULL DEFAULT NULL,
  `bid_increment` DECIMAL(10,2) NOT NULL DEFAULT 1.00,
  `auction_status` VARCHAR(16) NOT NULL DEFAULT 'open',
  `image` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner_identifier` (`owner_identifier`),
  KEY `idx_sale_type` (`sale_type`),
  KEY `idx_category` (`category`),
  KEY `idx_auction_status` (`auction_status`),
  KEY `idx_auction_end_time` (`auction_end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_purchases` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `buyer_identifier` VARCHAR(80) NOT NULL,
  `seller_identifier` VARCHAR(80) NOT NULL,
  `sale_id` INT NOT NULL,
  `product_name` VARCHAR(100) NOT NULL,
  `quantity` INT NOT NULL,
  `line_total` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_purchases_buyer` (`buyer_identifier`),
  KEY `idx_purchases_seller` (`seller_identifier`),
  KEY `idx_purchases_sale` (`sale_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_seller_ratings` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `purchase_id` INT NOT NULL,
  `buyer_identifier` VARCHAR(80) NOT NULL,
  `seller_identifier` VARCHAR(80) NOT NULL,
  `stars` TINYINT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rating_purchase` (`purchase_id`),
  KEY `idx_ratings_seller` (`seller_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_seller_rating_stats` (
  `seller_identifier` VARCHAR(80) NOT NULL,
  `total_stars` BIGINT NOT NULL DEFAULT 0,
  `rating_count` INT NOT NULL DEFAULT 0,
  `avg_rating` DECIMAL(4,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`seller_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_bids` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `sale_id` INT NOT NULL,
  `bidder_identifier` VARCHAR(80) NOT NULL,
  `bid_amount` DECIMAL(10,2) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bids_sale` (`sale_id`),
  KEY `idx_bids_bidder` (`bidder_identifier`),
  KEY `idx_bids_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_seller_wallet` (
  `owner_identifier` VARCHAR(80) NOT NULL,
  `balance` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `total_sales` INT NOT NULL DEFAULT 0,
  `total_revenue` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `total_withdrawn` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_coupons` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(32) NOT NULL,
  `discount_type` VARCHAR(16) NOT NULL,
  `discount_value` DECIMAL(10,2) NOT NULL,
  `max_uses` INT NULL DEFAULT NULL,
  `used_count` INT NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(80) NOT NULL DEFAULT '',
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_coupon_code` (`code`),
  KEY `idx_coupon_active` (`is_active`),
  KEY `idx_coupon_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_reports` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `listing_id` INT NOT NULL,
  `reporter_id` VARCHAR(80) NOT NULL,
  `seller_id` VARCHAR(80) NOT NULL,
  `reason` VARCHAR(32) NOT NULL,
  `description` TEXT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_reports_listing_reporter` (`listing_id`, `reporter_id`),
  KEY `idx_reports_status` (`status`),
  KEY `idx_reports_reason` (`reason`),
  KEY `idx_reports_listing` (`listing_id`),
  KEY `idx_reports_seller` (`seller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bd_commerce_blocked_sellers` (
  `seller_id` VARCHAR(80) NOT NULL,
  `reason` VARCHAR(120) NOT NULL DEFAULT 'Banned by moderation',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`seller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
