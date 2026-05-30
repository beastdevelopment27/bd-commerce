const DEFAULT_INVENTORY_IMAGE_PATH = "ox_inventory/web/images";
const DEFAULT_PANEL_TITLE = "ABay";
const DEFAULT_PANEL_SUBTITLE = "System to Sell and Buy items";

export const ITEM_IMAGE_PLACEHOLDER =
  "https://placehold.co/80x80/101010/ffffff?text=S";

let inventoryImagePath = DEFAULT_INVENTORY_IMAGE_PATH;
let panelTitle = DEFAULT_PANEL_TITLE;
let panelSubtitle = DEFAULT_PANEL_SUBTITLE;

export function setCommerceImagePath(path: string | undefined) {
  if (typeof path === "string" && path.trim() !== "") {
    inventoryImagePath = path.trim().replace(/\/+$/, "");
  }
}

export function getCommerceImagePath() {
  return inventoryImagePath;
}

export function setCommercePanelBranding(
  title: string | undefined,
  subtitle: string | undefined,
) {
  if (typeof title === "string" && title.trim() !== "") {
    panelTitle = title.trim();
  }
  if (typeof subtitle === "string" && subtitle.trim() !== "") {
    panelSubtitle = subtitle.trim();
  }
}

export function getCommercePanelTitle() {
  return panelTitle;
}

export function getCommercePanelSubtitle() {
  return panelSubtitle;
}

export type CommerceMetaBranding = {
  inventoryImagePath?: string;
  panelTitle?: string;
  panelSubtitle?: string;
};

export function applyCommerceMeta(meta: CommerceMetaBranding | undefined) {
  if (!meta) return;
  setCommerceImagePath(meta.inventoryImagePath);
  setCommercePanelBranding(meta.panelTitle, meta.panelSubtitle);
}
