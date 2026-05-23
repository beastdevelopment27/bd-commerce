-- Allow auction_status to be unset for non-auction listings (Person, Job, Public, etc.)
ALTER TABLE `bd_commerce_sales`
  MODIFY COLUMN `auction_status` VARCHAR(16) NULL DEFAULT NULL;
