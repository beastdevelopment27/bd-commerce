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
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxGroup,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  ComboboxTrigger,
} from "@/components/ui/combobox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { fetchNui } from "@/utils/fetchNui";
import { Pencil, Search, Trash2 } from "lucide-react";
import { memo, useCallback, useDeferredValue, useEffect, useMemo, useRef, useState } from "react";

import { getImageUrl } from "@/utils/misc";
import { saleTabMockSales } from "@/mocks/saleTabMockData";

type SaleType = "Public" | "Person" | "Job" | "Auction";

type SalePayload = {
  productName: string;
  description: string;
  inventoryItem: string;
  playerTarget: string;
  jobTarget: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: SaleType;
  category: string;
  startingPrice?: string;
  bidIncrement?: string;
  auctionDurationMinutes?: string;
};

type CreateSaleResponse = {
  ok: boolean;
  message: string;
  sale?: SaleItem;
};

type SaleItem = {
  id: string;
  productName: string;
  description: string;
  image: string;
  inventoryItem: string;
  playerTarget: string;
  jobTarget?: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: SaleType;
  category?: string;
  startingPrice?: string;
  currentHighestBid?: string;
  auctionEndTime?: string;
  bidIncrement?: string;
  auctionStatus?: string;
};

type InventoryItem = {
  name: string;
  label: string;
  count: number;
  image?: string;
};

type InventoryItemsResponse = {
  ok: boolean;
  message: string;
  items: InventoryItem[];
};

type MySalesResponse = {
  ok: boolean;
  message: string;
  sales: SaleItem[];
};

type UpdateSaleResponse = {
  ok: boolean;
  message: string;
  sale?: SaleItem;
};

type PlayerSearchResult = {
  serverId: number;
  name: string;
  identifier: string;
};

type PlayerSearchResponse = {
  ok: boolean;
  message: string;
  players: PlayerSearchResult[];
};

type JobTargetOption = {
  value: string;
  label: string;
};

type JobTargetsResponse = {
  ok: boolean;
  message: string;
  jobs: JobTargetOption[];
};

type CommerceMetaResponse = {
  ok: boolean;
  message: string;
  categories: Array<{ id: string; label: string }>;
};

type SaleCardProps = {
  sale: SaleItem;
  index: number;
  placeholderItemImage: string;
  onEdit: (saleId: string) => void;
  onDelete: (saleId: string) => void;
};

const SaleCard = memo(function SaleCard({
  sale,
  index,
  placeholderItemImage,
  onEdit,
  onDelete,
}: SaleCardProps) {
  const rawSaleTotal = (Number(sale.quantity) || 0) * (Number(sale.price) || 0);
  const saleDiscount = Math.min(Math.max(Number(sale.discount) || 0, 0), 100);
  const saleTotal = rawSaleTotal - (rawSaleTotal * saleDiscount) / 100;
  const stockCount = Number(sale.quantity) || 0;
  const stockLabel = stockCount <= 0 ? "Sold Out" : stockCount <= 5 ? "Low Stock" : "In Stock";
  const stockClassName =
    stockCount <= 0
      ? "border border-red-500/40 bg-red-500/20 text-red-300"
      : stockCount <= 5
        ? "border border-amber-500/40 bg-amber-500/20 text-amber-300"
        : "border border-emerald-500/40 bg-emerald-500/20 text-emerald-300";
  const badgeClassName =
    index % 2 === 0
      ? "bg-[var(--ds-accent-primary)]/20 text-[var(--ds-accent-primary)]"
      : "bg-[var(--ds-status-info)]/20 text-[var(--ds-status-info)]";

  return (
    <div className="group flex h-full flex-col rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 p-3">
      <div className="relative mb-3 flex h-36 items-center justify-center rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/60 p-2">
        {sale.image ? (
          <img
            src={getImageUrl(
              `${sale.inventoryItem}.png` as string,
              "ox_inventory/web/images",
              placeholderItemImage,
            )}
            alt={sale.productName}
            className="h-full w-full rounded-md object-contain"
            onError={(event) => {
              event.currentTarget.src = placeholderItemImage;
            }}
          />
        ) : (
          <div
            className={`flex h-16 w-16 shrink-0 items-center justify-center rounded-lg text-2xl font-semibold ${badgeClassName}`}
            aria-hidden
          >
            {sale.productName.charAt(sale.productName.length - 1)}
          </div>
        )}
      </div>

      <div className="flex min-h-0 flex-1 flex-col">
        <p className="truncate text-base font-semibold text-[var(--ds-text-primary)]">
          {sale.productName}
        </p>
        <p className="truncate text-xs text-[var(--ds-text-secondary)]">
          {sale.saleType === "Person"
            ? "Personal Sale"
            : sale.saleType === "Job"
              ? "Job Sale"
              : "Public Sale"}
        </p>
        <p
          className="mt-1 line-clamp-2 min-h-[1rem] max-h-[1rem] overflow-hidden text-xs text-[var(--ds-text-muted)]"
          title={sale.description}
        >
          {sale.description}
        </p>
      </div>

      <div className="mt-3 space-y-2">
        <div className="flex items-center justify-between">
          <p className="text-lg font-semibold text-[var(--ds-text-primary)]">${saleTotal.toFixed(2)}</p>
          {saleDiscount > 0 ? (
            <p className="text-xs font-semibold text-[var(--ds-status-info)]">{saleDiscount}% OFF</p>
          ) : null}
        </div>
        <div className="flex items-center justify-between">
          <p className="text-xs text-[var(--ds-text-muted)]">Qty: {sale.quantity}</p>
          <span
            className={`rounded-full px-2 py-1 text-[10px] font-semibold uppercase tracking-wide ${stockClassName}`}
          >
            {stockLabel}
          </span>
        </div>
      </div>

      <div className="mt-3 flex items-center gap-2 border-t border-[var(--ds-border-subtle)] pt-3">
        <div className="flex w-full flex-row gap-2">
          <Button
            size="sm"
            variant="secondary"
            className="h-9 flex-1 rounded-md px-3"
            onClick={() => onEdit(sale.id)}
          >
            <Pencil className="h-4 w-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="h-9 flex-1 rounded-md px-3 text-[var(--ds-status-error)] hover:bg-[var(--ds-status-error-soft)] hover:text-[var(--ds-status-error)]"
            onClick={() => onDelete(sale.id)}
          >
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>
  );
});

export default function SaleTab() {
  const formFieldClassName =
    "shadow-none focus-visible:shadow-none focus-visible:ring-0 focus-visible:ring-offset-0";
  const [open, setOpen] = useState(false);
  const [editingSaleId, setEditingSaleId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [saleTypeFilter, setSaleTypeFilter] = useState<string>("all");
  const [priceMin, setPriceMin] = useState("");
  const [priceMax, setPriceMax] = useState("");
  const [onSaleOnly, setOnSaleOnly] = useState(false);
  const [hideSoldOut, setHideSoldOut] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoadingInventory, setIsLoadingInventory] = useState(false);
  const [isSearchingPlayers, setIsSearchingPlayers] = useState(false);
  const [playerSearchQuery, setPlayerSearchQuery] = useState("");
  const [playerSearchResults, setPlayerSearchResults] = useState<PlayerSearchResult[]>([]);
  const [inventoryItems, setInventoryItems] = useState<InventoryItem[]>([]);
  const [jobTargetOptions, setJobTargetOptions] = useState<JobTargetOption[]>([]);
  const [categoryOptions, setCategoryOptions] = useState<Array<{ id: string; label: string }>>([]);
  const [formData, setFormData] = useState<SalePayload>({
    productName: "",
    description: "",
    inventoryItem: "",
    playerTarget: "",
    jobTarget: "",
    quantity: "",
    price: "",
    discount: "",
    saleType: "Public",
    category: "misc",
    startingPrice: "",
    bidIncrement: "1",
    auctionDurationMinutes: "60",
  });
  const [sales, setSales] = useState<SaleItem[]>([]);
  const placeholderItemImage = "https://placehold.co/80x80/101010/ffffff?text=S";
  const isMountedRef = useRef(true);
  const searchRequestIdRef = useRef(0);
  const hasLoadedDialogDataRef = useRef(false);

  useEffect(() => {
    return () => {
      isMountedRef.current = false;
    };
  }, []);

  const deferredSearch = useDeferredValue(searchTerm);
  const deferredCategoryFilter = useDeferredValue(categoryFilter);
  const deferredSaleTypeFilter = useDeferredValue(saleTypeFilter);
  const deferredPriceMin = useDeferredValue(priceMin);
  const deferredPriceMax = useDeferredValue(priceMax);
  const deferredOnSaleOnly = useDeferredValue(onSaleOnly);
  const deferredHideSoldOut = useDeferredValue(hideSoldOut);

  const filteredSales = useMemo(() => {
    const needle = deferredSearch.trim().toLowerCase();
    let list = sales;

    if (deferredCategoryFilter !== "all") {
      list = list.filter((sale) => (sale.category || "misc") === deferredCategoryFilter);
    }

    if (deferredSaleTypeFilter !== "all") {
      list = list.filter((sale) => sale.saleType === deferredSaleTypeFilter);
    }

    if (deferredOnSaleOnly) {
      list = list.filter((sale) => (Number(sale.discount) || 0) > 0);
    }

    if (deferredHideSoldOut) {
      list = list.filter((sale) => (Number(sale.quantity) || 0) > 0);
    }

    const minValue = parseFloat(deferredPriceMin);
    if (!Number.isNaN(minValue)) {
      list = list.filter((sale) => (Number(sale.price) || 0) >= minValue);
    }
    const maxValue = parseFloat(deferredPriceMax);
    if (!Number.isNaN(maxValue)) {
      list = list.filter((sale) => (Number(sale.price) || 0) <= maxValue);
    }

    if (!needle) return list;
    return list.filter((sale) =>
      [
        sale.productName,
        sale.description,
        sale.inventoryItem,
        sale.playerTarget,
        sale.saleType,
      ]
        .join(" ")
        .toLowerCase()
        .includes(needle),
    );
  }, [
    deferredCategoryFilter,
    deferredHideSoldOut,
    deferredOnSaleOnly,
    deferredPriceMax,
    deferredPriceMin,
    deferredSaleTypeFilter,
    deferredSearch,
    sales,
  ]);

  const selectedInventoryItem = useMemo(
    () => inventoryItems.find((item) => item.name === formData.inventoryItem) ?? null,
    [inventoryItems, formData.inventoryItem],
  );
  const selectedInventoryCount = selectedInventoryItem?.count ?? 0;
  const playerComboboxData = useMemo(() => {
    const mapped = playerSearchResults.map((player) => ({
      label: player.name,
      value: player.name,
    }));

    if (
      playerSearchQuery &&
      !mapped.some((entry) => entry.value === playerSearchQuery)
    ) {
      mapped.unshift({
        label: playerSearchQuery,
        value: playerSearchQuery,
      });
    }

    return mapped;
  }, [playerSearchResults, playerSearchQuery]);

  const displayedSales = useMemo(() => filteredSales.slice(0, 50), [filteredSales]);
  const hasMoreSales = filteredSales.length > displayedSales.length;

  const handleInputChange = useCallback((field: keyof typeof formData, value: string) => {
    setFormData((prev) => {
      if (field === "saleType") {
        const nextSaleType: SaleType =
          value === "Person" || value === "Job" || value === "Auction" ? value : "Public";
        return {
          ...prev,
          saleType: nextSaleType,
          playerTarget: nextSaleType === "Person" ? prev.playerTarget : "",
          jobTarget: nextSaleType === "Job" ? prev.jobTarget : "",
          discount: nextSaleType === "Auction" ? "0" : prev.discount,
        };
      }

      return {
        ...prev,
        [field]:
          field === "quantity" && selectedInventoryCount > 0
            ? String(Math.min(Number(value) || 0, selectedInventoryCount))
            : value,
      };
    });
  }, [selectedInventoryCount]);

  const loadInventoryItems = useCallback(async () => {
    setIsLoadingInventory(true);
    const response = await fetchNui<InventoryItemsResponse>(
      "getInventoryItems",
      {},
      {
        ok: true,
        message: "Inventory loaded (browser mock).",
        items: [
          {
            name: "water",
            label: "Water",
            count: 10,
            image: "https://placehold.co/24x24/101010/ffffff?text=W",
          },
          {
            name: "bread",
            label: "Bread",
            count: 5,
            image: "https://placehold.co/24x24/101010/ffffff?text=B",
          },
          {
            name: "repair-kit",
            label: "Repair Kit",
            count: 2,
            image: "https://placehold.co/24x24/101010/ffffff?text=R",
          },
        ],
      },
    ).catch(
      (): InventoryItemsResponse => ({
        ok: false,
        message: "Failed to load inventory items.",
        items: [],
      }),
    );
    if (!isMountedRef.current) return;
    setIsLoadingInventory(false);

    if (!response.ok) {
      setSubmitError(response.message || "Failed to load inventory items.");
      return;
    }

    setInventoryItems(response.items || []);
  }, []);

  const loadJobTargets = useCallback(async () => {
    const response = await fetchNui<JobTargetsResponse>(
      "getJobTargets",
      {},
      {
        ok: true,
        message: "Job list loaded (browser mock).",
        jobs: [
          { value: "police", label: "Police" },
          { value: "ambulance", label: "Ambulance" },
          { value: "mechanic", label: "Mechanic" },
        ],
      },
    ).catch(
      (): JobTargetsResponse => ({
        ok: false,
        message: "Failed to load jobs.",
        jobs: [],
      }),
    );

    if (!response.ok) {
      if (!isMountedRef.current) return;
      setSubmitError(response.message || "Failed to load jobs.");
      return;
    }

    if (!isMountedRef.current) return;
    setJobTargetOptions(response.jobs || []);
  }, []);

  const loadCommerceMeta = useCallback(async () => {
    const response = await fetchNui<CommerceMetaResponse>(
      "getCommerceMeta",
      {},
      {
        ok: true,
        message: "OK",
        categories: [
          { id: "misc", label: "Misc" },
          { id: "weapons", label: "Weapons" },
          { id: "food", label: "Food & Drinks" },
        ],
      },
    ).catch(
      (): CommerceMetaResponse => ({
        ok: false,
        message: "Failed.",
        categories: [],
      }),
    );

    if (!isMountedRef.current) return;
    if (response.ok && Array.isArray(response.categories)) {
      setCategoryOptions(response.categories);
    }
  }, []);

  const loadMySales = useCallback(async () => {
    const response = await fetchNui<MySalesResponse>(
      "getMySales",
      {},
      {
        ok: true,
        message: "Sales loaded (browser mock).",
        sales: saleTabMockSales,
      },
    ).catch(
      (): MySalesResponse => ({
        ok: false,
        message: "Failed to load your sales.",
        sales: [],
      }),
    );

    if (!response.ok) {
      if (!isMountedRef.current) return;
      setSubmitError(response.message || "Failed to load your sales.");
      return;
    }

    if (!isMountedRef.current) return;
    setSales(response.sales || []);
  }, []);

  useEffect(() => {
    loadMySales();
  }, [loadMySales]);

  useEffect(() => {
    if (!open) return;
    setSubmitError("");
    if (!hasLoadedDialogDataRef.current) {
      hasLoadedDialogDataRef.current = true;
      loadInventoryItems();
      loadJobTargets();
      void loadCommerceMeta();
    }
  }, [open, loadCommerceMeta, loadInventoryItems, loadJobTargets]);

  useEffect(() => {
    if (!open || formData.saleType !== "Person") return;

    const query = playerSearchQuery.trim();
    const isNumericQuery = /^\d+$/.test(query);
    if (!isNumericQuery && query.length < 3) {
      setPlayerSearchResults([]);
      setIsSearchingPlayers(false);
      return;
    }

    const timer = setTimeout(async () => {
      const requestId = searchRequestIdRef.current + 1;
      searchRequestIdRef.current = requestId;
      setIsSearchingPlayers(true);
      const response = await fetchNui<PlayerSearchResponse>(
        "searchPlayerTargets",
        { query },
        {
          ok: true,
          message: "Player search mock.",
          players: [],
        },
      ).catch(
        (): PlayerSearchResponse => ({
          ok: false,
          message: "Player search failed.",
          players: [],
        }),
      );
      if (!isMountedRef.current || searchRequestIdRef.current !== requestId) return;
      setIsSearchingPlayers(false);

      if (!response.ok) {
        setSubmitError(response.message || "Failed to search players.");
        return;
      }

      setPlayerSearchResults(response.players || []);
    }, 300);

    return () => clearTimeout(timer);
  }, [open, formData.saleType, playerSearchQuery]);

  const resetForm = useCallback(() => {
    setFormData({
      productName: "",
      description: "",
      inventoryItem: "",
      playerTarget: "",
      jobTarget: "",
      quantity: "",
      price: "",
      discount: "",
      saleType: "Public",
      category: "misc",
      startingPrice: "",
      bidIncrement: "1",
      auctionDurationMinutes: "60",
    });
  }, []);

  const handleSubmit = useCallback(async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitError("");

    if (!editingSaleId && selectedInventoryCount > 0) {
      const requestedQuantity = Number(formData.quantity) || 0;
      if (requestedQuantity > selectedInventoryCount) {
        setSubmitError(
          `Quantity cannot be higher than inventory count (${selectedInventoryCount}).`,
        );
        return;
      }
    }

    if (formData.saleType === "Person" && !formData.playerTarget.trim()) {
      setSubmitError("Please select a valid online player target.");
      return;
    }

    if (formData.saleType === "Job" && !formData.jobTarget.trim()) {
      setSubmitError("Please select a job target.");
      return;
    }
    if (formData.saleType === "Auction") {
      const startingPrice = Number(formData.startingPrice || formData.price || 0);
      const bidIncrement = Number(formData.bidIncrement || 0);
      const duration = Number(formData.auctionDurationMinutes || 0);
      if (startingPrice < 0) {
        setSubmitError("Starting price must be 0 or greater.");
        return;
      }
      if (bidIncrement <= 0) {
        setSubmitError("Bid increment must be greater than 0.");
        return;
      }
      if (duration < 1) {
        setSubmitError("Auction duration must be at least 1 minute.");
        return;
      }
    }

    if (editingSaleId) {
      const response = await fetchNui<UpdateSaleResponse>(
        "updateSale",
        {
          id: editingSaleId,
          ...formData,
        },
        {
          ok: true,
          message: "Sale updated (browser mock).",
          sale: {
            id: editingSaleId,
            ...formData,
            image: "",
          },
        },
      ).catch(
        (): UpdateSaleResponse => ({
          ok: false,
          message: "Failed to contact game client.",
        }),
      );

      if (!isMountedRef.current) return;
      if (!response.ok) {
        setSubmitError(response.message || "Failed to update sale.");
        return;
      }

      if (response.sale) {
        setSales((prev) =>
          prev.map((sale) => (sale.id === editingSaleId ? response.sale! : sale)),
        );
      } else {
        await loadMySales();
      }
      setOpen(false);
      setEditingSaleId(null);
      resetForm();
      return;
    }

    const payload: SalePayload = {
      ...formData,
      discount: formData.discount || "0",
    };

    setIsSubmitting(true);
    const response: CreateSaleResponse = await fetchNui<CreateSaleResponse>(
      "createSale",
      payload,
      {
        ok: true,
        message: "Sale created (browser mock).",
        sale: {
          id: `sale-${Date.now()}`,
          ...payload,
          image: "",
        },
      },
    ).catch(
      (): CreateSaleResponse => ({
        ok: false,
        message: "Failed to contact game client.",
      }),
    );
    if (!isMountedRef.current) return;
    setIsSubmitting(false);

    if (!response.ok) {
      setSubmitError(response.message || "Failed to create sale.");
      return;
    }

    if (response.sale) {
      const createdSale = response.sale;
      setSales((prev) => [createdSale, ...prev]);
    } else {
      await loadMySales();
    }
    await loadInventoryItems();
    setOpen(false);
    setEditingSaleId(null);
    setPlayerSearchQuery("");
    setPlayerSearchResults([]);
    resetForm();
  }, [
    editingSaleId,
    formData,
    isSubmitting,
    playerSearchResults,
    resetForm,
    loadInventoryItems,
    loadMySales,
    selectedInventoryCount,
  ]);

  const handleDialogOpenChange = useCallback((value: boolean) => {
    setOpen(value);
    if (!value) {
      setSubmitError("");
      setPlayerSearchQuery("");
      setPlayerSearchResults([]);
      if (!editingSaleId) {
        resetForm();
      }
    }
  }, [editingSaleId, resetForm]);

  const effectiveBasePrice =
    formData.saleType === "Auction"
      ? Number(formData.startingPrice || formData.price || 0)
      : Number(formData.price) || 0;
  const baseTotal = (Number(formData.quantity) || 0) * effectiveBasePrice;
  const discountPercent = Math.min(Math.max(Number(formData.discount) || 0, 0), 100);
  const totalSale = baseTotal - (baseTotal * discountPercent) / 100;

  const handleEdit = useCallback((saleId: string) => {
    const selectedSale = sales.find((sale) => sale.id === saleId);
    if (!selectedSale) return;

    setFormData({
      productName: selectedSale.productName,
      description: selectedSale.description,
      inventoryItem: selectedSale.inventoryItem,
      playerTarget: selectedSale.playerTarget,
      jobTarget: selectedSale.jobTarget || "",
      quantity: selectedSale.quantity,
      price: selectedSale.price,
      discount: selectedSale.discount,
      saleType: selectedSale.saleType as SaleType,
      category: selectedSale.category || "misc",
      startingPrice: selectedSale.startingPrice || selectedSale.price,
      bidIncrement: selectedSale.bidIncrement || "1",
      auctionDurationMinutes: "60",
    });
    setPlayerSearchQuery(selectedSale.playerTarget || "");
    setPlayerSearchResults([]);
    setEditingSaleId(saleId);
    setOpen(true);
  }, [sales]);

  const handleDelete = useCallback((saleId: string) => {
    setSales((prev) => prev.filter((sale) => sale.id !== saleId));
  }, []);

  return (
    <>
      <div className="mb-4 flex items-start justify-between gap-4">
        <div className="space-y-0.5">
          <h1 className="text-xl font-semibold leading-tight text-[var(--ds-text-primary)]">
            Sales
          </h1>
          <p className="text-sm text-[var(--ds-text-secondary)]">
            Create and manage sale listings
          </p>
        </div>

        <div className="flex w-full max-w-[420px] items-center justify-end gap-2">
          <Dialog open={open} onOpenChange={handleDialogOpenChange}>
            <div className="flex w-full max-w-[420px] items-center gap-2">
              <div className="relative flex-1">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--ds-text-muted)]" />
                <Input
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  placeholder="Search sales..."
                  className="h-10 pl-9 shadow-none focus-visible:shadow-none focus-visible:ring-0 focus-visible:ring-offset-0"
                  aria-label="Search sales"
                />
              </div>
              <DialogTrigger asChild>
                <Button className="h-10 px-4">Create Sale</Button>
              </DialogTrigger>
            </div>
            <DialogContent className="shadow-none duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none md:max-h-[80vh] md:overflow-y-auto lg:max-h-none lg:overflow-visible">
              <DialogHeader>
                <DialogTitle>{editingSaleId ? "Edit Sale" : "Create Sale"}</DialogTitle>
                <DialogDescription>
                  Fill in the details below to add a new sale listing.
                </DialogDescription>
              </DialogHeader>
              <form className="grid gap-4" onSubmit={handleSubmit}>
                <div className="grid gap-2">
                  <Label htmlFor="productName">Product Name</Label>
                  <Input
                    id="productName"
                    placeholder="Enter product name"
                    value={formData.productName}
                    className={formFieldClassName}
                    onChange={(event) =>
                      handleInputChange("productName", event.target.value)
                    }
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="description">Description</Label>
                  <Input
                    id="description"
                    placeholder="Enter product description"
                    value={formData.description}
                    className={formFieldClassName}
                    onChange={(event) =>
                      handleInputChange("description", event.target.value)
                    }
                    required
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="category">Category</Label>
                  <Select
                    value={formData.category}
                    onValueChange={(value) => handleInputChange("category", value)}
                  >
                    <SelectTrigger id="category" className={formFieldClassName}>
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      {(categoryOptions.length > 0
                        ? categoryOptions
                        : [{ id: "misc", label: "Misc" }]
                      ).map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="inventoryItem">Inventory Item</Label>
                  <Select
                    value={formData.inventoryItem}
                    onValueChange={(value) =>
                      handleInputChange("inventoryItem", value)
                    }
                    disabled={Boolean(editingSaleId)}
                  >
                    <SelectTrigger id="inventoryItem" className={formFieldClassName}>
                      <SelectValue placeholder="Select inventory item" />
                    </SelectTrigger>
                    <SelectContent className="max-h-48">
                      {inventoryItems.map((item) => (
                        <SelectItem key={item.name} value={item.name}>
                          {item.label} ({item.count})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  {!isLoadingInventory && inventoryItems.length === 0 ? (
                    <p className="text-xs text-[var(--ds-text-muted)]">
                      No inventory items found.
                    </p>
                  ) : null}
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="quantity">Quantity</Label>
                  <Input
                    id="quantity"
                    type="number"
                    placeholder="1"
                    value={formData.quantity}
                    className={formFieldClassName}
                    onChange={(event) =>
                      handleInputChange("quantity", event.target.value)
                    }
                    min="1"
                    max={selectedInventoryCount > 0 ? String(selectedInventoryCount) : undefined}
                    disabled={Boolean(editingSaleId)}
                    readOnly={Boolean(editingSaleId)}
                    required
                  />
                  {!editingSaleId && formData.inventoryItem ? (
                    <p className="text-xs text-[var(--ds-text-muted)]">
                      Available: {selectedInventoryCount}
                    </p>
                  ) : null}
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="saleType">Sale Type</Label>
                  <Select
                    value={formData.saleType}
                    onValueChange={(value) => handleInputChange("saleType", value)}
                  >
                    <SelectTrigger id="saleType" className={formFieldClassName}>
                      <SelectValue placeholder="Select sale type" />
                    </SelectTrigger>
                    <SelectContent className="max-h-48">
                      <SelectItem value="Public">Public</SelectItem>
                      <SelectItem value="Person">Person</SelectItem>
                      <SelectItem value="Job">Job</SelectItem>
                      <SelectItem value="Auction">Auction</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="price">{formData.saleType === "Auction" ? "Starting Price" : "Price"}</Label>
                  <Input
                    id="price"
                    type="number"
                    placeholder="0.00"
                    value={formData.saleType === "Auction" ? formData.startingPrice : formData.price}
                    className={formFieldClassName}
                    onChange={(event) =>
                      handleInputChange(
                        formData.saleType === "Auction" ? "startingPrice" : "price",
                        event.target.value,
                      )
                    }
                    min="0"
                    step="0.01"
                    required
                  />
                </div>
                {formData.saleType === "Auction" ? (
                  <>
                    <div className="grid gap-2">
                      <Label htmlFor="bidIncrement">Bid Increment</Label>
                      <Input
                        id="bidIncrement"
                        type="number"
                        value={formData.bidIncrement}
                        className={formFieldClassName}
                        onChange={(event) => handleInputChange("bidIncrement", event.target.value)}
                        min="0.01"
                        step="0.01"
                        required
                      />
                    </div>
                    <div className="grid gap-2">
                      <Label htmlFor="auctionDurationMinutes">Duration (minutes)</Label>
                      <Input
                        id="auctionDurationMinutes"
                        type="number"
                        value={formData.auctionDurationMinutes}
                        className={formFieldClassName}
                        onChange={(event) =>
                          handleInputChange("auctionDurationMinutes", event.target.value)
                        }
                        min="1"
                        step="1"
                        required
                      />
                    </div>
                  </>
                ) : null}
                {editingSaleId ? (
                  <div className="grid gap-2">
                    <Label htmlFor="discount">Discount %</Label>
                    <Input
                      id="discount"
                      type="number"
                      placeholder="0"
                      value={formData.discount}
                      className={formFieldClassName}
                      onChange={(event) =>
                        handleInputChange("discount", event.target.value)
                      }
                      min="0"
                      max="100"
                      step="1"
                    />
                  </div>
                ) : null}
                {formData.saleType === "Person" ? (
                  <div className="grid gap-2">
                    <Label htmlFor="playerTarget">Player Name</Label>
                    <Combobox
                      data={playerComboboxData}
                      type="player"
                      value={playerSearchQuery}
                      onValueChange={(value) => {
                        const selected = playerSearchResults.find(
                          (player) => player.name === value,
                        );
                        if (selected) {
                          setPlayerSearchQuery(selected.name);
                          handleInputChange("playerTarget", selected.identifier);
                        } else {
                          setPlayerSearchQuery(value);
                          handleInputChange("playerTarget", "");
                        }
                      }}
                    >
                      <ComboboxTrigger className={formFieldClassName} />
                      <ComboboxContent
                        className="z-[120] border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)] opacity-100 shadow-xl"
                        popoverOptions={{ side: "top", align: "start", sideOffset: 6 }}
                      >
                        <ComboboxInput
                          value={playerSearchQuery}
                          onValueChange={(value) => {
                            setPlayerSearchQuery(value);
                            handleInputChange("playerTarget", "");
                          }}
                        />
                        <ComboboxList>
                          <ComboboxEmpty />
                          <ComboboxGroup>
                            {playerSearchResults.map((player) => (
                              <ComboboxItem
                                key={`${player.serverId}-${player.identifier}`}
                                value={player.name}
                              >
                                {player.name}
                              </ComboboxItem>
                            ))}
                          </ComboboxGroup>
                        </ComboboxList>
                      </ComboboxContent>
                    </Combobox>
                  </div>
                ) : null}
                {formData.saleType === "Job" ? (
                  <div className="grid gap-2">
                    <Label htmlFor="jobTarget">Job Name</Label>
                    <Select
                      value={formData.jobTarget}
                      onValueChange={(value) => handleInputChange("jobTarget", value)}
                    >
                      <SelectTrigger id="jobTarget" className={formFieldClassName}>
                        <SelectValue placeholder="Select job target" />
                      </SelectTrigger>
                      <SelectContent className="max-h-48">
                        {jobTargetOptions.map((job) => (
                          <SelectItem key={job.value} value={job.value}>
                            {job.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                ) : null}
                <div className="grid gap-2">
                  <Label htmlFor="totalSale">Total Sale</Label>
                  <Input
                    id="totalSale"
                    type="number"
                    value={Number.isNaN(totalSale) ? "0.00" : totalSale.toFixed(2)}
                    className={formFieldClassName}
                    min="0"
                    step="0.01"
                    disabled
                    readOnly
                  />
                </div>
                {submitError ? (
                  <p className="text-sm text-[var(--ds-status-error)]">{submitError}</p>
                ) : null}
                <DialogFooter>
                  <Button type="button" variant="secondary" onClick={() => setOpen(false)}>
                    Cancel
                  </Button>
                  <Button type="submit" disabled={isSubmitting}>
                    {editingSaleId ? "Update Sale" : "Create Sale"}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>
      <div className="mb-4 flex flex-wrap items-end gap-2 rounded-lg bg-[var(--ds-bg-elevated)]/35 px-3 py-2">
        <div className="grid gap-1">
          <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Category</Label>
          <Select value={categoryFilter} onValueChange={setCategoryFilter}>
            <SelectTrigger className="h-9 w-[165px]">
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
            onChange={(event) => setPriceMin(event.target.value)}
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
            onChange={(event) => setPriceMax(event.target.value)}
            className="h-9 w-28"
            placeholder="—"
          />
        </div>
        <Button
          type="button"
          size="sm"
          variant={onSaleOnly ? "default" : "secondary"}
          className="h-9"
          onClick={() => setOnSaleOnly((prev) => !prev)}
        >
          On sale
        </Button>
        <Button
          type="button"
          size="sm"
          variant={hideSoldOut ? "default" : "secondary"}
          className="h-9"
          onClick={() => setHideSoldOut((prev) => !prev)}
        >
          Hide sold out
        </Button>
      </div>
      <div className="min-h-0 flex-1 overflow-auto rounded-xl bg-[var(--ds-bg-card)]/70 p-3">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-5">
          {displayedSales.map((sale, index) => (
            <SaleCard
              key={sale.id}
              sale={sale}
              index={index}
              placeholderItemImage={placeholderItemImage}
              onEdit={handleEdit}
              onDelete={handleDelete}
            />
          ))}
          {hasMoreSales ? (
            <div className="col-span-full rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 px-4 py-3 text-center text-xs text-[var(--ds-text-muted)]">
              Showing first 50 sales for smooth performance. Refine search to narrow results.
            </div>
          ) : null}
          {filteredSales.length === 0 ? (
            <div className="col-span-full rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/45 px-4 py-8 text-center text-sm text-[var(--ds-text-secondary)]">
              No sales found for your search.
            </div>
          ) : null}
        </div>
      </div>
    </>
  );
}