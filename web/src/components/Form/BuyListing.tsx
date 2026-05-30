import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";
import { buyListingMockSales } from "@/mocks/buyListingMockData";
import { fetchNui } from "@/utils/fetchNui";
import { applyCommerceMeta, ITEM_IMAGE_PLACEHOLDER } from "@/lib/commerceConfig";
import { getImageUrl } from "@/utils/misc";
import { AlertTriangle, Search, ShoppingCart, Star } from "lucide-react";
import type { HTMLAttributes } from "react";
import {
  forwardRef,
  memo,
  useCallback,
  useDeferredValue,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { VirtuosoGrid } from "react-virtuoso";

type CartItem = {
  id: string;
  name: string;
  unitPrice: number;
  quantity: number;
};

type PublicSaleItem = {
  id: string;
  productName: string;
  description: string;
  inventoryItem: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: string;
  jobTarget?: string;
  image: string;
  category?: string;
  sellerRatingAvg?: number | null;
  sellerRatingCount?: number;
  owner?: string;
  startingPrice?: string;
  currentHighestBid?: string;
  highestBidder?: string;
  auctionEndTime?: string;
  bidIncrement?: string;
  auctionStatus?: string;
};

type PublicSalesResponse = {
  ok: boolean;
  message: string;
  sales: PublicSaleItem[];
};

type PendingRatingItem = {
  purchaseId: number;
  sellerIdentifier: string;
  sellerName: string;
  productName: string;
};

type CheckoutResponse = {
  ok: boolean;
  message: string;
  sales: PublicSaleItem[];
  receivedItems?: Array<{ item: string; amount: number }>;
  pendingRatings?: PendingRatingItem[];
};

type CommerceMetaResponse = {
  ok: boolean;
  message?: string;
  categories: Array<{ id: string; label: string }>;
  inventoryImagePath?: string;
  panelTitle?: string;
  panelSubtitle?: string;
};

type SubmitRatingResponse = {
  ok: boolean;
  message?: string;
};

type SubmitReportResponse = {
  ok: boolean;
  message: string;
};

type CheckoutPaymentMethod = "cash" | "bank";
type CouponDiscountType = "percent" | "fixed";

type ValidateCouponResponse = {
  ok: boolean;
  message: string;
  code?: string;
  discountType?: CouponDiscountType;
  discountValue?: number;
};
const PUBLIC_SALES_REFRESH_MS = 15000;

type ListingItem = {
  id: string;
  name: string;
  description: string;
  quantity: number;
  price: number;
  discountPercent?: number;
  image?: string;
  inventoryItem: string;
  saleType: string;
  jobTarget?: string;
  category: string;
  effectivePrice: number;
  sellerRatingAvg: number | null;
  sellerRatingCount: number;
  owner: string;
  searchText: string;
  startingPrice?: number;
  currentHighestBid?: number | null;
  highestBidder?: string;
  auctionEndTime?: string;
  bidIncrement?: number;
  auctionStatus?: string;
};

const mapPublicSalesToItems = (sales: PublicSaleItem[]): ListingItem[] =>
  (sales || []).map((sale) => {
    const normalizedSaleType = (sale.saleType || "Public").trim();
    const normalizedAuctionStatus = (sale.auctionStatus || "open").trim().toLowerCase();
    const discountPercent = Number(sale.discount) || 0;
    const basePrice = Number(sale.price) || 0;
    const effectivePrice =
      discountPercent > 0
        ? basePrice - (basePrice * discountPercent) / 100
        : basePrice;
    const category = (sale.category || "misc").toLowerCase();
    return {
      id: sale.id,
      name: sale.productName,
      description: sale.description,
      inventoryItem: sale.inventoryItem,
      quantity: Number(sale.quantity) || 0,
      price: basePrice,
      discountPercent,
      image: sale.image,
      saleType: normalizedSaleType,
      jobTarget: sale.jobTarget || "",
      category,
      effectivePrice,
      sellerRatingAvg:
        typeof sale.sellerRatingAvg === "number" && (sale.sellerRatingCount ?? 0) > 0
          ? sale.sellerRatingAvg
          : null,
      sellerRatingCount: sale.sellerRatingCount ?? 0,
      owner: sale.owner || "",
      searchText: `${sale.productName} ${sale.description} ${sale.saleType || "Public"} ${sale.jobTarget || ""} ${category}`.toLowerCase(),
      startingPrice: Number(sale.startingPrice) || basePrice,
      currentHighestBid:
        typeof sale.currentHighestBid === "string" && sale.currentHighestBid !== ""
          ? Number(sale.currentHighestBid)
          : null,
      highestBidder: sale.highestBidder || "",
      auctionEndTime: sale.auctionEndTime,
      bidIncrement: Number(sale.bidIncrement) || 1,
      auctionStatus: normalizedAuctionStatus,
    };
  });

const ProductCard = memo(function ProductCard({
  item,
  inCartQuantity,
  onAddToCart,
  onBid,
  onIncrement,
  onDecrement,
  onReport,
}: {
  item: ListingItem;
  inCartQuantity: number;
  onAddToCart: (item: ListingItem) => void;
  onBid: (item: ListingItem) => void;
  onIncrement: (itemId: string) => void;
  onDecrement: (itemId: string) => void;
  onReport: (item: ListingItem) => void;
}) {
  const safeDiscountPercent = Math.min(Math.max(item.discountPercent ?? 0, 0), 100);
  const basePrice = Number(item.price.toFixed(2));
  const hasDiscount = safeDiscountPercent >= 0.01;
  const displayPrice = hasDiscount
    ? Number((basePrice * (1 - safeDiscountPercent / 100)).toFixed(2))
    : basePrice;
  const isOutOfStockForCart = inCartQuantity >= item.quantity;
  const isAuction = item.saleType.trim().toLowerCase() === "auction";
  const isAuctionOpen = (item.auctionStatus || "open").trim().toLowerCase() === "open";
  const auctionTopBid =
    item.currentHighestBid != null ? item.currentHighestBid : item.startingPrice || item.price;
  const stockLabel =
    item.quantity <= 0 ? "Sold Out" : item.quantity <= 5 ? "Low Stock" : "In Stock";
  const stockClassName =
    item.quantity <= 0
      ? "border border-red-500/40 bg-red-500/20 text-red-300"
      : item.quantity <= 5
        ? "border border-amber-500/40 bg-amber-500/20 text-amber-300"
        : "border border-emerald-500/40 bg-emerald-500/20 text-emerald-300";

  return (
    <div className="group flex h-[470px] flex-col rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/55 p-3">
      <div className="relative mb-3 flex h-44 items-center justify-center rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/70 p-2">
        <img
          src={getImageUrl(item.image, undefined, ITEM_IMAGE_PLACEHOLDER)}
          alt={item.name}
          className="h-full w-full rounded-md object-contain"
          onError={(event) => {
            event.currentTarget.src = ITEM_IMAGE_PLACEHOLDER;
          }}
        />
      </div>

      <div className="flex min-h-0 flex-1 flex-col">
        <p
          className="line-clamp-2 min-h-10 text-base font-semibold leading-5 tracking-[0.01em] text-white"
          style={{ textDecoration: "none" }}
          title={item.name || "Unnamed item"}
        >
          {item.name || "Unnamed item"}
        </p>
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="rounded bg-[var(--ds-bg-card)]/80 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-[var(--ds-text-muted)]">
            {item.category}
          </span>
          <p
            className={`truncate text-xs ${
              item.saleType === "Person"
                ? "text-[var(--ds-status-warning)]"
                : item.saleType === "Job"
                  ? "text-[var(--ds-status-success)]"
                  : item.saleType === "Auction"
                    ? "text-[var(--ds-status-info)]"
                  : "text-[var(--ds-text-secondary)]"
            }`}
          >
            {item.saleType === "Person"
              ? "Personal Sale"
              : item.saleType === "Job"
                ? "Job Sale"
                : item.saleType === "Auction"
                  ? "Auction"
                : "Public Sale"}
          </p>
        </div>
        {item.sellerRatingCount > 0 && item.sellerRatingAvg != null ? (
          <p className="mt-0.5 flex items-center gap-1 text-[10px] text-amber-300/60">
            <Star className="h-2.5 w-2.5 fill-amber-300/60 text-amber-300/60" aria-hidden />
            <span className="font-medium">{item.sellerRatingAvg.toFixed(1)}</span>
            <span className="text-[var(--ds-text-muted)]/70">({item.sellerRatingCount})</span>
          </p>
        ) : (
          <p className="mt-0.5 text-[10px] text-[var(--ds-text-muted)]">No seller ratings yet</p>
        )}
        <p
          className="mt-1 line-clamp-2 min-h-8 shrink-0 text-xs leading-4 text-slate-300 [overflow-wrap:anywhere] break-words"
          style={{ textDecoration: "none" }}
          title={item.description || "No description"}
        >
          {item.description || "No description"}
        </p>
      </div>

      <div className="mt-5 min-h-[4.2rem]">
        <div className="flex min-h-[2.6rem] items-end justify-between">
          <div className="min-h-[2.6rem]">
            {hasDiscount ? (
              <>
                <p className="text-[11px] leading-tight text-[var(--ds-text-muted)]/85">
                  <del className="decoration-[1.5px] decoration-[var(--ds-text-muted)]/70">
                    ${basePrice.toFixed(2)}
                  </del>
                </p>
                <p className="text-lg font-semibold leading-tight text-[var(--ds-text-primary)]">
                  ${isAuction ? auctionTopBid.toFixed(2) : displayPrice.toFixed(2)}
                </p>
              </>
            ) : (
              <p className="text-lg font-semibold leading-tight text-[var(--ds-text-primary)]">
                ${isAuction ? auctionTopBid.toFixed(2) : displayPrice.toFixed(2)}
              </p>
            )}
          </div>
          {hasDiscount ? (
            <p className="text-xs font-semibold text-[var(--ds-status-info)]">
              {Number(safeDiscountPercent.toFixed(2))}% OFF
            </p>
          ) : (
            <p className="text-xs font-semibold opacity-0">0% OFF</p>
          )}
        </div>
        <div className="mt-2 flex items-center justify-between">
          <p className="text-xs text-[var(--ds-text-muted)]">Qty: {item.quantity}</p>
          <span
            className={`rounded-full px-2 py-1 text-[10px] font-semibold uppercase tracking-wide ${stockClassName}`}
          >
            {stockLabel}
          </span>
        </div>
      </div>

      <div className="mt-4 border-t border-[var(--ds-border-subtle)] pt-3">
        {inCartQuantity > 0 ? (
          <div className="flex h-9 items-center justify-between gap-2 rounded-md bg-[var(--ds-bg-card)]/60 px-2">
            <p className="text-xs font-medium text-[var(--ds-text-secondary)]">Quantity to add</p>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                size="sm"
                variant="secondary"
                className="h-7 w-7 rounded-md px-0"
                onClick={() => onDecrement(item.id)}
              >
                -
              </Button>
              <span className="w-6 text-center text-sm font-semibold text-[var(--ds-text-primary)]">
                {inCartQuantity}
              </span>
              <Button
                type="button"
                size="sm"
                variant="secondary"
                className="h-7 w-7 rounded-md px-0"
                onClick={() => onIncrement(item.id)}
                disabled={isOutOfStockForCart}
              >
                +
              </Button>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                className="h-7 w-7 rounded-md px-0 text-[var(--ds-status-warning)]"
                onClick={() => onReport(item)}
              >
                <AlertTriangle className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-[1fr_auto] gap-2">
            <Button
              size="sm"
              className="h-9 w-full justify-center rounded-md px-3"
              onClick={() => (isAuction ? onBid(item) : onAddToCart(item))}
              disabled={isAuction ? !isAuctionOpen : item.quantity <= 0}
            >
              <ShoppingCart className="h-4 w-4" />
              {isAuction ? "Place Bid" : "Add to Cart"}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              className="h-9 rounded-md px-2 text-[var(--ds-status-warning)] hover:bg-[var(--ds-status-warning-soft)] hover:text-[var(--ds-status-warning)]"
              onClick={() => onReport(item)}
            >
              <AlertTriangle className="h-4 w-4" />
            </Button>
          </div>
        )}
      </div>
    </div>
  );
});

const MarketplaceGrid = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  function MarketplaceGrid({ className, style, ...props }, ref) {
    return (
      <div
        ref={ref}
        {...props}
        style={style}
        className={cn(
          "grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-5",
          className,
        )}
      />
    );
  },
);

export default function BuyListing() {
  const [searchTerm, setSearchTerm] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [saleTypeFilter, setSaleTypeFilter] = useState<string>("all");
  const [priceMin, setPriceMin] = useState("");
  const [priceMax, setPriceMax] = useState("");
  const [onSaleOnly, setOnSaleOnly] = useState(false);
  const [hideSoldOut, setHideSoldOut] = useState(true);
  const [categoryOptions, setCategoryOptions] = useState<Array<{ id: string; label: string }>>([]);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [isPaymentMethodOpen, setIsPaymentMethodOpen] = useState(false);
  const [isCheckingOut, setIsCheckingOut] = useState(false);
  const [couponCode, setCouponCode] = useState("");
  const [couponMessage, setCouponMessage] = useState("");
  const [couponError, setCouponError] = useState("");
  const [isApplyingCoupon, setIsApplyingCoupon] = useState(false);
  const [appliedCoupon, setAppliedCoupon] = useState<{
    code: string;
    discountType: CouponDiscountType;
    discountValue: number;
  } | null>(null);
  const [cart, setCart] = useState<Record<string, CartItem>>({});
  const [items, setItems] = useState<ListingItem[]>([]);
  const [ratingQueue, setRatingQueue] = useState<PendingRatingItem[]>([]);
  const [ratingSelections, setRatingSelections] = useState<Record<number, number>>({});
  const [isRatingOpen, setIsRatingOpen] = useState(false);
  const [isSubmittingRating, setIsSubmittingRating] = useState(false);
  const [isReportOpen, setIsReportOpen] = useState(false);
  const [reportListing, setReportListing] = useState<ListingItem | null>(null);
  const [reportReason, setReportReason] = useState<"Scam" | "Wrong Price" | "Abuse">("Scam");
  const [reportDescription, setReportDescription] = useState("");
  const [isSubmittingReport, setIsSubmittingReport] = useState(false);
  const [reportMessage, setReportMessage] = useState("");
  const [isBidOpen, setIsBidOpen] = useState(false);
  const [bidListing, setBidListing] = useState<ListingItem | null>(null);
  const [bidAmountInput, setBidAmountInput] = useState("");
  const [isSubmittingBid, setIsSubmittingBid] = useState(false);
  const [bidFeedback, setBidFeedback] = useState("");
  const isLoadingPublicSalesRef = useRef(false);
  const isCheckingOutRef = useRef(false);

  const loadCommerceMeta = useCallback(async () => {
    const response = await fetchNui<CommerceMetaResponse>(
      "getCommerceMeta",
      {},
      {
        ok: true,
        categories: [
          { id: "misc", label: "Misc" },
          { id: "weapons", label: "Weapons" },
          { id: "food", label: "Food & Drinks" },
        ],
      },
    ).catch(
      (): CommerceMetaResponse => ({
        ok: false,
        categories: [],
      }),
    );
    if (response.ok) {
      applyCommerceMeta(response);
      if (Array.isArray(response.categories)) {
        setCategoryOptions(response.categories);
      }
    }
  }, []);

  const loadPublicSales = useCallback(async () => {
    if (isLoadingPublicSalesRef.current || isCheckingOutRef.current) return;
    isLoadingPublicSalesRef.current = true;
    const response = await fetchNui<PublicSalesResponse>(
      "getPublicSales",
      {},
      {
        ok: true,
        message: "Public sales loaded (browser mock).",
        sales: buyListingMockSales,
      },
    ).catch(
      (): PublicSalesResponse => ({
        ok: false,
        message: "Failed to load public sales.",
        sales: [],
      }),
    );
    isLoadingPublicSalesRef.current = false;
    if (!response.ok) return;
    setItems(mapPublicSalesToItems(response.sales || []));
  }, []);

  useEffect(() => {
    isCheckingOutRef.current = isCheckingOut;
  }, [isCheckingOut]);

  useEffect(() => {
    void loadCommerceMeta();
  }, [loadCommerceMeta]);

  useEffect(() => {
    loadPublicSales();
    const interval = window.setInterval(() => {
      if (typeof document !== "undefined" && document.hidden) return;
      loadPublicSales();
    }, PUBLIC_SALES_REFRESH_MS);

    return () => window.clearInterval(interval);
  }, [loadPublicSales]);

  const deferredSearchTerm = useDeferredValue(searchTerm);
  const deferredCategory = useDeferredValue(categoryFilter);
  const deferredSaleType = useDeferredValue(saleTypeFilter);
  const deferredPriceMin = useDeferredValue(priceMin);
  const deferredPriceMax = useDeferredValue(priceMax);
  const deferredOnSale = useDeferredValue(onSaleOnly);
  const deferredHideSoldOut = useDeferredValue(hideSoldOut);

  const filteredItems = useMemo(() => {
    const needle = deferredSearchTerm.trim().toLowerCase();
    let list = items;

    if (deferredHideSoldOut) {
      list = list.filter((item) => item.quantity > 0);
    }

    if (deferredCategory !== "all") {
      list = list.filter((item) => item.category === deferredCategory);
    }

    if (deferredSaleType !== "all") {
      list = list.filter((item) => item.saleType === deferredSaleType);
    }

    if (deferredOnSale) {
      list = list.filter((item) => (item.discountPercent ?? 0) > 0);
    }

    const pMin = parseFloat(deferredPriceMin);
    const pMax = parseFloat(deferredPriceMax);
    if (!Number.isNaN(pMin)) {
      list = list.filter((item) => item.effectivePrice >= pMin);
    }
    if (!Number.isNaN(pMax)) {
      list = list.filter((item) => item.effectivePrice <= pMax);
    }

    if (!needle) return list;
    return list.filter((item) => item.searchText.includes(needle));
  }, [
    deferredSearchTerm,
    deferredCategory,
    deferredSaleType,
    deferredPriceMin,
    deferredPriceMax,
    deferredOnSale,
    deferredHideSoldOut,
    items,
  ]);

  const itemQuantitiesById = useMemo(() => {
    const lookup: Record<string, number> = {};
    for (const item of items) {
      lookup[item.id] = item.quantity;
    }
    return lookup;
  }, [items]);

  const cartItems = useMemo(() => Object.values(cart), [cart]);
  const cartItemCount = useMemo(
    () => cartItems.reduce((sum, item) => sum + item.quantity, 0),
    [cartItems],
  );
  const cartTotal = useMemo(
    () => cartItems.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0),
    [cartItems],
  );
  const couponDiscountAmount = useMemo(() => {
    if (!appliedCoupon || cartTotal <= 0) return 0;
    if (appliedCoupon.discountType === "percent") {
      return Math.min(cartTotal, (cartTotal * appliedCoupon.discountValue) / 100);
    }
    return Math.min(cartTotal, appliedCoupon.discountValue);
  }, [appliedCoupon, cartTotal]);
  const payableTotal = useMemo(
    () => Math.max(cartTotal - couponDiscountAmount, 0),
    [cartTotal, couponDiscountAmount],
  );

  const handleAddToCart = useCallback((item: ListingItem) => {
    const unitPrice = item.effectivePrice;

    setCart((prev) => {
      const existing = prev[item.id];
      if (existing) {
        if (existing.quantity >= item.quantity) return prev;
        return {
          ...prev,
          [item.id]: { ...existing, quantity: existing.quantity + 1 },
        };
      }

      return {
        ...prev,
        [item.id]: {
          id: item.id,
          name: item.name,
          unitPrice,
          quantity: 1,
        },
      };
    });
  }, []);

  const handlePlaceBid = useCallback((item: ListingItem) => {
    const suggestedMin = Number(
      (
        (item.currentHighestBid != null ? item.currentHighestBid : item.startingPrice || item.price) +
        (item.bidIncrement || 1)
      ).toFixed(2),
    );
    setBidListing(item);
    setBidAmountInput(suggestedMin.toFixed(2));
    setBidFeedback("");
    setIsBidOpen(true);
  }, []);

  const handleSubmitBid = useCallback(async () => {
    if (!bidListing || isSubmittingBid) return;
    const amount = Number(bidAmountInput);
    if (!Number.isFinite(amount) || amount <= 0) {
      setBidFeedback("Invalid bid amount.");
      return;
    }
    const suggestedMin = Number(
      (
        (bidListing.currentHighestBid != null ? bidListing.currentHighestBid : bidListing.startingPrice || bidListing.price) +
        (bidListing.bidIncrement || 1)
      ).toFixed(2),
    );
    if (amount < suggestedMin) {
      setBidFeedback(`Minimum bid is $${suggestedMin.toFixed(2)}.`);
      return;
    }
    setIsSubmittingBid(true);
    setBidFeedback("");
    const response = await fetchNui<{ ok: boolean; message?: string }>(
      "placeBid",
      { id: bidListing.id, amount: amount.toFixed(2) },
      { ok: true, message: "Bid placed (browser mock)." },
    ).catch(() => ({ ok: false, message: "Failed to place bid." }));
    setIsSubmittingBid(false);
    setReportMessage(response.message || (response.ok ? "Bid placed." : "Failed to place bid."));
    if (response.ok) {
      setIsBidOpen(false);
      setBidListing(null);
      setBidAmountInput("");
      setBidFeedback("");
      await loadPublicSales();
    } else {
      setBidFeedback(response.message || "Failed to place bid.");
    }
  }, [bidAmountInput, bidListing, isSubmittingBid, loadPublicSales]);

  const incrementCartItem = useCallback((itemId: string) => {
    setCart((prev) => {
      const selected = prev[itemId];
      if (!selected) return prev;
      const maxAllowed = itemQuantitiesById[itemId] ?? 0;
      if (selected.quantity >= maxAllowed) return prev;
      return {
        ...prev,
        [itemId]: { ...selected, quantity: selected.quantity + 1 },
      };
    });
  }, [itemQuantitiesById]);

  const decrementCartItem = useCallback((itemId: string) => {
    setCart((prev) => {
      const selected = prev[itemId];
      if (!selected) return prev;
      if (selected.quantity <= 1) {
        const { [itemId]: _, ...rest } = prev;
        return rest;
      }
      return {
        ...prev,
        [itemId]: { ...selected, quantity: selected.quantity - 1 },
      };
    });
  }, []);

  const clearCart = () => {
    setCart({});
    setCouponCode("");
    setAppliedCoupon(null);
    setCouponMessage("");
    setCouponError("");
  };

  const handleApplyCoupon = async () => {
    if (isApplyingCoupon || isCheckingOut) return;
    const normalizedCode = couponCode.trim().toUpperCase();
    setCouponMessage("");
    setCouponError("");

    if (!normalizedCode) {
      setCouponError("Please enter coupon code.");
      return;
    }

    if (cartTotal <= 0) {
      setCouponError("Add items to cart before applying coupon.");
      return;
    }

    setIsApplyingCoupon(true);
    const response = await fetchNui<ValidateCouponResponse>(
      "validateCoupon",
      {
        code: normalizedCode,
        amount: cartTotal,
        saleIds: cartItems.map((item) => item.id),
      },
      {
        ok: normalizedCode === "BDWELCOME10" || normalizedCode === "BDFLAT50",
        message:
          normalizedCode === "BDWELCOME10" || normalizedCode === "BDFLAT50"
            ? "Coupon applied."
            : "Coupon not available.",
        code: normalizedCode,
        discountType: normalizedCode === "BDFLAT50" ? "fixed" : "percent",
        discountValue: normalizedCode === "BDFLAT50" ? 50 : 10,
      },
    ).catch(
      (): ValidateCouponResponse => ({
        ok: false,
        message: "Failed to validate coupon.",
      }),
    );
    setIsApplyingCoupon(false);

    if (
      !response.ok ||
      !response.discountType ||
      typeof response.discountValue !== "number"
    ) {
      setAppliedCoupon(null);
      setCouponError(response.message || "Not available coupon code.");
      return;
    }

    setAppliedCoupon({
      code: response.code || normalizedCode,
      discountType: response.discountType,
      discountValue: response.discountValue,
    });
    setCouponMessage(response.message || "Coupon applied.");
    setCouponCode(response.code || normalizedCode);
  };

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null);
    setCouponMessage("");
    setCouponError("");
    setCouponCode("");
  };

  const handleCheckout = async (paymentMethod: CheckoutPaymentMethod) => {
    if (cartItems.length === 0 || isCheckingOut) return;
    setIsCheckingOut(true);
    const purchasedById: Record<string, number> = {};
    for (const item of cartItems) {
      purchasedById[item.id] = item.quantity;
    }

    const response = await fetchNui<CheckoutResponse>(
      "checkoutCart",
      {
        items: cartItems.map((item) => ({
          id: item.id,
          quantity: item.quantity,
        })),
        paymentMethod,
        couponCode: appliedCoupon?.code || null,
      },
      {
        ok: true,
        message: "Checkout completed (browser mock).",
        sales: [],
        pendingRatings: [],
      },
    ).catch(
      (): CheckoutResponse => ({
        ok: false,
        message: "Failed to checkout cart.",
        sales: [],
      }),
    );

    if (response.ok) {
      setItems((prev) =>
        prev.map((item) => {
          const purchased = purchasedById[item.id];
          if (!purchased) return item;
          const nextQuantity = Math.max(item.quantity - purchased, 0);
          if (nextQuantity === item.quantity) return item;
          return {
            ...item,
            quantity: nextQuantity,
          };
        }),
      );
      setCart({});
      setCouponCode("");
      setAppliedCoupon(null);
      setCouponMessage("");
      setCouponError("");
      setIsPaymentMethodOpen(false);

      const pending = response.pendingRatings;
      if (pending && pending.length > 0) {
        const defaults: Record<number, number> = {};
        for (const p of pending) {
          defaults[p.purchaseId] = 5;
        }
        setRatingSelections(defaults);
        setRatingQueue(pending);
        setIsRatingOpen(true);
      }
    }

    if (Array.isArray(response.sales) && response.sales.length > 0) {
      setItems(mapPublicSalesToItems(response.sales));
    } else {
      void loadPublicSales();
    }

    setIsCheckingOut(false);
  };

  const handleSubmitRatings = useCallback(async () => {
    if (ratingQueue.length === 0 || isSubmittingRating) return;
    setIsSubmittingRating(true);
    try {
      let hadFailure = false;
      for (const entry of ratingQueue) {
        const stars = ratingSelections[entry.purchaseId] ?? 5;
        const res = await fetchNui<SubmitRatingResponse>(
          "submitSellerRating",
          { purchaseId: entry.purchaseId, stars },
          { ok: true, message: "Thanks!" },
        ).catch(
          (): SubmitRatingResponse => ({
            ok: false,
            message: "Failed to submit rating.",
          }),
        );
        if (!res.ok) {
          hadFailure = true;
          break;
        }
      }
      setIsRatingOpen(false);
      setRatingQueue([]);
      setRatingSelections({});
      if (hadFailure) {
        setCouponError("Some ratings could not be submitted. Checkout is still completed.");
      } else {
        setCouponError("");
      }
      void loadPublicSales();
    } finally {
      setIsSubmittingRating(false);
    }
  }, [isSubmittingRating, ratingQueue, ratingSelections, loadPublicSales]);

  const handleOpenReport = useCallback((item: ListingItem) => {
    setReportListing(item);
    setReportReason("Scam");
    setReportDescription("");
    setReportMessage("");
    setIsReportOpen(true);
  }, []);

  const handleSubmitReport = useCallback(async () => {
    if (!reportListing || isSubmittingReport) return;
    setIsSubmittingReport(true);
    const response = await fetchNui<SubmitReportResponse>(
      "submitReport",
      {
        listingId: reportListing.id,
        reason: reportReason,
        description: reportDescription.trim(),
      },
      {
        ok: true,
        message: "Report submitted.",
      },
    ).catch(
      (): SubmitReportResponse => ({
        ok: false,
        message: "Failed to submit report.",
      }),
    );
    setIsSubmittingReport(false);
    setReportMessage(response.message || (response.ok ? "Report submitted." : "Failed to submit report."));
    if (response.ok) {
      setTimeout(() => {
        setIsReportOpen(false);
      }, 600);
    }
  }, [isSubmittingReport, reportDescription, reportListing, reportReason]);

  const getItemBadgeClassName = (index: number) =>
    index % 2 === 0
      ? "bg-[var(--ds-accent-primary)]/20 text-[var(--ds-accent-primary)]"
      : "bg-[var(--ds-status-info)]/20 text-[var(--ds-status-info)]";

  return (
    <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div className="mb-4 space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="space-y-0.5">
          <h2 className="text-xl font-semibold leading-tight text-[var(--ds-text-primary)]">
            Products
          </h2>
          <p className="text-sm text-[var(--ds-text-secondary)]">
            Browse and manage your products
          </p>
        </div>

        <div className="flex w-full max-w-[460px] items-center gap-2">
          <div className="relative flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--ds-text-muted)]" />
            <Input
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Search products..."
              className="h-10 pl-9 shadow-none focus-visible:shadow-none focus-visible:ring-0 focus-visible:ring-offset-0"
              aria-label="Search products"
            />
          </div>
          <Dialog open={isCartOpen} onOpenChange={setIsCartOpen}>
            <DialogTrigger asChild>
              <Button type="button" className="h-10 rounded-md px-4">
                <ShoppingCart className="h-4 w-4" />
                Cart ({cartItemCount})
              </Button>
            </DialogTrigger>
            <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[560px]">
              <DialogHeader>
                <DialogTitle>Cart</DialogTitle>
                <DialogDescription>
                  Review selected products before checkout.
                </DialogDescription>
              </DialogHeader>

              <div className="max-h-[360px] space-y-2 overflow-auto pr-1">
                {cartItems.length > 0 ? (
                  cartItems.map((item) => (
                    <div
                      key={item.id}
                      className="flex items-center justify-between rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 p-3"
                    >
                      <div className="min-w-0">
                        <p className="truncate font-medium text-[var(--ds-text-primary)]">
                          {item.name}
                        </p>
                        <p className="text-sm text-[var(--ds-text-secondary)]">
                          ${item.unitPrice.toFixed(2)} each
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <Button
                          type="button"
                          size="sm"
                          variant="secondary"
                          className="h-8 w-8 rounded-md px-0"
                          onClick={() => decrementCartItem(item.id)}
                        >
                          -
                        </Button>
                        <span className="w-7 text-center text-sm font-medium text-[var(--ds-text-primary)]">
                          {item.quantity}
                        </span>
                        <Button
                          type="button"
                          size="sm"
                          variant="secondary"
                          className="h-8 w-8 rounded-md px-0"
                          onClick={() => incrementCartItem(item.id)}
                          disabled={
                            item.quantity >=
                            (itemQuantitiesById[item.id] ?? 0)
                          }
                        >
                          +
                        </Button>
                      </div>
                      <p className="w-24 text-right font-medium text-[var(--ds-text-primary)]">
                        ${(item.unitPrice * item.quantity).toFixed(2)}
                      </p>
                    </div>
                  ))
                ) : (
                  <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 px-4 py-8 text-center text-sm text-[var(--ds-text-secondary)]">
                    Your cart is empty.
                  </div>
                )}
              </div>

              <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 px-3 py-2">
                <div className="mb-2 grid gap-2">
                  <span className="text-sm text-[var(--ds-text-secondary)]">Coupon Code</span>
                  <div className="flex gap-2">
                    <Input
                      value={couponCode}
                      onChange={(event) => setCouponCode(event.target.value.toUpperCase())}
                      placeholder="Enter coupon code"
                      className="h-9"
                    />
                    <Button
                      type="button"
                      variant="secondary"
                      className="h-9"
                      disabled={isApplyingCoupon || cartItems.length === 0}
                      onClick={handleApplyCoupon}
                    >
                      {isApplyingCoupon ? "Applying..." : "Apply"}
                    </Button>
                  </div>
                  {couponError ? (
                    <p className="text-xs text-[var(--ds-status-error)]">
                      {couponError || "Not available coupon code."}
                    </p>
                  ) : null}
                  {couponMessage && appliedCoupon ? (
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-xs text-[var(--ds-status-success)]">
                        {couponMessage} ({appliedCoupon.code})
                      </p>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        className="h-6 px-2 text-xs text-[var(--ds-status-error)] hover:bg-[var(--ds-status-error-soft)] hover:text-[var(--ds-status-error)]"
                        onClick={handleRemoveCoupon}
                      >
                        X Remove
                      </Button>
                    </div>
                  ) : null}
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-[var(--ds-text-secondary)]">Items</span>
                  <span className="font-medium text-[var(--ds-text-primary)]">
                    {cartItemCount}
                  </span>
                </div>
                <div className="mt-1 flex items-center justify-between">
                  <span className="text-sm text-[var(--ds-text-secondary)]">Total</span>
                  <span className="text-lg font-semibold text-[var(--ds-text-primary)]">
                    ${cartTotal.toFixed(2)}
                  </span>
                </div>
                {appliedCoupon ? (
                  <div className="mt-1 flex items-center justify-between">
                    <span className="text-sm text-[var(--ds-text-secondary)]">Coupon Discount</span>
                    <span className="font-medium text-[var(--ds-status-success)]">
                      -${couponDiscountAmount.toFixed(2)}
                    </span>
                  </div>
                ) : null}
                <div className="mt-1 flex items-center justify-between">
                  <span className="text-sm text-[var(--ds-text-secondary)]">Payable</span>
                  <span className="text-lg font-semibold text-[var(--ds-text-primary)]">
                    ${payableTotal.toFixed(2)}
                  </span>
                </div>
              </div>

              <DialogFooter>
                <Button type="button" variant="secondary" onClick={clearCart}>
                  Clear Cart
                </Button>
                <Button
                  type="button"
                  onClick={() => setIsPaymentMethodOpen(true)}
                  disabled={cartItems.length === 0 || isCheckingOut}
                >
                  Checkout
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
          <Dialog open={isPaymentMethodOpen} onOpenChange={setIsPaymentMethodOpen}>
            <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[420px]">
              <DialogHeader>
                <DialogTitle>Select Payment Method</DialogTitle>
                <DialogDescription>
                  Choose where to deduct money for this checkout.
                </DialogDescription>
              </DialogHeader>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <Button
                  type="button"
                  variant="secondary"
                  disabled={isCheckingOut}
                  onClick={() => handleCheckout("cash")}
                >
                  {isCheckingOut ? "Processing..." : "Pay With Cash"}
                </Button>
                <Button
                  type="button"
                  disabled={isCheckingOut}
                  onClick={() => handleCheckout("bank")}
                >
                  {isCheckingOut ? "Processing..." : "Pay With Bank"}
                </Button>
              </div>
            </DialogContent>
          </Dialog>
        </div>
      </div>

        <div className="flex flex-wrap items-end gap-2 rounded-lg bg-[var(--ds-bg-elevated)]/35 px-3 py-2">
          <div className="grid w-[250px] gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Category</Label>
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="h-9 w-full min-w-[250px] max-w-[250px] bg-[var(--ds-bg-card)]">
                <SelectValue placeholder="All categories" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All categories</SelectItem>
                {categoryOptions.map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Min $</Label>
            <Input
              type="number"
              min={0}
              step={1}
              value={priceMin}
              onChange={(e) => setPriceMin(e.target.value)}
              className="h-9 w-28"
              placeholder="—"
            />
          </div>
          <div className="grid gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Max $</Label>
            <Input
              type="number"
              min={0}
              step={1}
              value={priceMax}
              onChange={(e) => setPriceMax(e.target.value)}
              className="h-9 w-28"
              placeholder="—"
            />
          </div>
          <Button
            type="button"
            size="sm"
            variant={onSaleOnly ? "default" : "secondary"}
            className="h-9"
            onClick={() => setOnSaleOnly((v) => !v)}
          >
            On sale
          </Button>
          <Button
            type="button"
            size="sm"
            variant={hideSoldOut ? "default" : "secondary"}
            className="h-9"
            onClick={() => setHideSoldOut((v) => !v)}
          >
            Hide sold out
          </Button>
        </div>
      </div>

      <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl bg-[var(--ds-bg-card)]/70 p-3">
        {filteredItems.length === 0 ? (
          <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 px-4 py-8 text-center text-sm text-[var(--ds-text-secondary)]">
            No products match your filters.
          </div>
        ) : (
          <VirtuosoGrid
            style={{ height: "100%", width: "100%" }}
            totalCount={filteredItems.length}
            increaseViewportBy={400}
            components={{ List: MarketplaceGrid }}
            itemContent={(index) => {
              const item = filteredItems[index];
              return (
                <ProductCard
                  item={item}
                  inCartQuantity={cart[item.id]?.quantity ?? 0}
                  onAddToCart={handleAddToCart}
                  onBid={handlePlaceBid}
                  onIncrement={incrementCartItem}
                  onDecrement={decrementCartItem}
                  onReport={handleOpenReport}
                />
              );
            }}
          />
        )}
      </div>

      <Dialog open={isReportOpen} onOpenChange={setIsReportOpen}>
        <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[520px]">
          <DialogHeader>
            <DialogTitle>Report listing</DialogTitle>
            <DialogDescription>
              Help moderation team review suspicious listings quickly.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <div className="grid gap-1">
              <Label>Listing</Label>
              <Input value={reportListing?.name || ""} readOnly />
            </div>
            <div className="grid gap-1">
              <Label>Reason</Label>
              <Select value={reportReason} onValueChange={(value) => setReportReason(value as "Scam" | "Wrong Price" | "Abuse")}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Scam">Scam</SelectItem>
                  <SelectItem value="Wrong Price">Wrong Price</SelectItem>
                  <SelectItem value="Abuse">Abuse</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-1">
              <Label>Details (optional)</Label>
              <Input
                value={reportDescription}
                onChange={(event) => setReportDescription(event.target.value)}
                placeholder="Additional context for admins..."
                maxLength={500}
              />
            </div>
            {reportMessage ? (
              <p className="text-xs text-[var(--ds-text-secondary)]">{reportMessage}</p>
            ) : null}
          </div>
          <DialogFooter>
            <Button type="button" variant="secondary" onClick={() => setIsReportOpen(false)}>
              Cancel
            </Button>
            <Button type="button" disabled={isSubmittingReport || !reportListing} onClick={() => void handleSubmitReport()}>
              {isSubmittingReport ? "Submitting..." : "Submit Report"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={isBidOpen} onOpenChange={setIsBidOpen}>
        <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[420px]">
          <DialogHeader>
            <DialogTitle>Place bid</DialogTitle>
            <DialogDescription>
              {bidListing ? `Enter bid for ${bidListing.name}.` : "Enter your bid amount."}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            {bidListing ? (
              <p className="text-xs text-[var(--ds-text-secondary)]">
                Minimum bid: $
                {(
                  (bidListing.currentHighestBid != null
                    ? bidListing.currentHighestBid
                    : bidListing.startingPrice || bidListing.price) + (bidListing.bidIncrement || 1)
                ).toFixed(2)}
              </p>
            ) : null}
            <div className="grid gap-1">
              <Label>Bid amount</Label>
              <Input
                type="number"
                min={0}
                step={0.01}
                value={bidAmountInput}
                onChange={(event) => setBidAmountInput(event.target.value)}
                placeholder="0.00"
              />
            </div>
            {bidFeedback ? (
              <p className="text-xs text-[var(--ds-status-error)]">{bidFeedback}</p>
            ) : null}
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                setIsBidOpen(false);
                setBidListing(null);
                setBidAmountInput("");
                setBidFeedback("");
              }}
            >
              Cancel
            </Button>
            <Button type="button" disabled={isSubmittingBid || !bidListing} onClick={() => void handleSubmitBid()}>
              {isSubmittingBid ? "Placing..." : "Place Bid"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={isRatingOpen} onOpenChange={setIsRatingOpen}>
        <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[480px]">
          <DialogHeader>
            <DialogTitle>Rate sellers</DialogTitle>
            <DialogDescription>
              Your purchase is complete. Rate each seller to help the marketplace stay trustworthy.
            </DialogDescription>
          </DialogHeader>
          <div className="max-h-[360px] space-y-4 overflow-auto pr-1">
            {ratingQueue.map((entry) => (
              <div
                key={entry.purchaseId}
                className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 p-3"
              >
                <p className="text-sm font-medium text-[var(--ds-text-primary)]">{entry.productName}</p>
                <p className="text-xs text-[var(--ds-text-muted)]">Seller: {entry.sellerName}</p>
                <div className="mt-2 flex gap-1">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      type="button"
                      className={cn(
                        "rounded p-1 transition-colors",
                        (ratingSelections[entry.purchaseId] ?? 5) >= star
                          ? "text-amber-300"
                          : "text-[var(--ds-text-muted)]",
                      )}
                      onClick={() =>
                        setRatingSelections((prev) => ({
                          ...prev,
                          [entry.purchaseId]: star,
                        }))
                      }
                    >
                      <Star className="h-5 w-5 fill-current" />
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                setIsRatingOpen(false);
                setRatingQueue([]);
                setRatingSelections({});
              }}
            >
              Skip
            </Button>
            <Button type="button" disabled={isSubmittingRating} onClick={() => void handleSubmitRatings()}>
              {isSubmittingRating ? "Submitting..." : "Submit ratings"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}
