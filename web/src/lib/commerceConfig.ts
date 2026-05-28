const DEFAULT_INVENTORY_IMAGE_PATH = "ox_inventory/web/images";

export const ITEM_IMAGE_PLACEHOLDER =
  "https://placehold.co/80x80/101010/ffffff?text=S";

let inventoryImagePath = DEFAULT_INVENTORY_IMAGE_PATH;

export function setCommerceImagePath(path: string | undefined) {
  if (typeof path === "string" && path.trim() !== "") {
    inventoryImagePath = path.trim();
  }
}

export function getCommerceImagePath() {
  return inventoryImagePath;
}
