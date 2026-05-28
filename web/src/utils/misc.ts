import { getCommerceImagePath } from "@/lib/commerceConfig";

// Will return whether the current environment is in a regular browser
// and not CEF
export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

// Basic no operation function
export const noop = () => { };

export const getImageUrl = (
    image: string | undefined,
    inventoryPath: string | undefined,
    fallback: string = "burger_chicken.png"
): string => {
    if (!image) return fallback;

    if (image.startsWith("http://") || image.startsWith("https://")) {
        return image;
    }

    if (isEnvBrowser()) {
        return fallback;
    }

    const path = inventoryPath ?? getCommerceImagePath();
    return `nui://${path}/${image}` || fallback;
};