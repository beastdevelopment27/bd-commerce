import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { adminSaleMockData } from "@/mocks/adminSaleMockData";
import { fetchNui } from "@/utils/fetchNui";
import { isEnvBrowser } from "@/utils/misc";
import { Pencil, Search, Trash2 } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

type SaleType = "Public" | "Person" | "Job";

type SaleItem = {
  id: string;
  productName: string;
  description: string;
  inventoryItem: string;
  playerTarget: string;
  jobTarget?: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: SaleType;
  category?: string;
  owner?: string;
  ownerName?: string;
  ownerIdentifier?: string;
  playerTargetName?: string;
  playerTargetIdentifier?: string;
  createdAt?: string;
};

type AdminSalesResponse = {
  ok: boolean;
  message: string;
  sales: SaleItem[];
  total?: number;
  page?: number;
  pageSize?: number;
};

type UpdateSaleResponse = {
  ok: boolean;
  message: string;
  sale?: SaleItem;
};

type DeleteSaleResponse = {
  ok: boolean;
  message: string;
};

const PAGE_SIZE = 10;

export default function AdminSale() {
  const [sales, setSales] = useState<SaleItem[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "empty">("all");
  const [categoryFilter, setCategoryFilter] = useState<"all" | SaleType>("all");
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [statusMessage, setStatusMessage] = useState("");
  const [editing, setEditing] = useState<SaleItem | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [editForm, setEditForm] = useState({
    productName: "",
    description: "",
    price: "",
    discount: "",
    saleType: "Public" as SaleType,
    playerTarget: "",
    jobTarget: "",
    category: "misc",
  });
  const isMountedRef = useRef(true);

  useEffect(() => {
    return () => {
      isMountedRef.current = false;
    };
  }, []);

  const loadSales = useCallback(async () => {
    setIsLoading(true);
    if (isEnvBrowser()) {
      const needle = searchTerm.trim().toLowerCase();
      const mockFiltered = adminSaleMockData.filter((sale) => {
        const stockQuantity = Number(sale.quantity) || 0;
        const matchesStatus =
          statusFilter === "all" ||
          (statusFilter === "active" && stockQuantity > 0) ||
          (statusFilter === "empty" && stockQuantity <= 0);
        const matchesCategory = categoryFilter === "all" || sale.saleType === categoryFilter;
        const matchesSearch =
          !needle ||
          [
            sale.productName,
            sale.description,
            sale.inventoryItem,
            sale.owner || "",
            sale.saleType,
            sale.playerTarget || "",
            sale.jobTarget || "",
          ]
            .join(" ")
            .toLowerCase()
            .includes(needle);
        return matchesStatus && matchesCategory && matchesSearch;
      });
      const startIndex = (page - 1) * PAGE_SIZE;
      const nextPageSales = mockFiltered.slice(startIndex, startIndex + PAGE_SIZE);
      setSales(nextPageSales);
      setTotalCount(mockFiltered.length);
      setIsLoading(false);
      return;
    }

    const response = await fetchNui<AdminSalesResponse>(
      "getAdminSales",
      {
        page,
        pageSize: PAGE_SIZE,
        search: searchTerm.trim(),
        status: statusFilter,
        saleType: categoryFilter,
      },
      {
        ok: true,
        message: "Admin sales mock.",
        sales: [],
        total: 0,
        page,
        pageSize: PAGE_SIZE,
      },
    ).catch(
      (): AdminSalesResponse => ({
        ok: false,
        message: "Failed to load sales.",
        sales: [],
        total: 0,
        page,
        pageSize: PAGE_SIZE,
      }),
    );

    if (!isMountedRef.current) return;
    if (response.ok) {
      const serverSales = Array.isArray(response.sales) ? response.sales : [];
      const serverHasPaginationMeta = typeof response.total === "number";
      const looksLikeUnpaginatedPayload = !serverHasPaginationMeta && serverSales.length > PAGE_SIZE;

      if (looksLikeUnpaginatedPayload) {
        const startIndex = (page - 1) * PAGE_SIZE;
        const pagedSales = serverSales.slice(startIndex, startIndex + PAGE_SIZE);
        setSales(pagedSales);
        setTotalCount(serverSales.length);
      } else {
        setSales(serverSales);
        setTotalCount(serverHasPaginationMeta ? (response.total as number) : serverSales.length);
      }
      setIsLoading(false);
      return;
    }
    setSales([]);
    setTotalCount(0);
    setIsLoading(false);
  }, [categoryFilter, page, searchTerm, statusFilter]);

  useEffect(() => {
    loadSales();
  }, [loadSales]);
  useEffect(() => {
    setPage(1);
  }, [categoryFilter, searchTerm, statusFilter]);

  const overviewStats = useMemo(() => {
    const totalSales = totalCount;
    const activeSales = sales.filter((sale) => (Number(sale.quantity) || 0) > 0).length;
    const totalRevenue = sales.reduce((sum, sale) => {
      const qty = Number(sale.quantity) || 0;
      const price = Number(sale.price) || 0;
      const discount = Math.min(Math.max(Number(sale.discount) || 0, 0), 100);
      return sum + qty * price * (1 - discount / 100);
    }, 0);
    return { totalSales, activeSales, totalRevenue };
  }, [sales]);

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));
  const visibleSales = useMemo(() => sales.slice(0, PAGE_SIZE), [sales]);

  const handleOpenEdit = useCallback((sale: SaleItem) => {
    setEditing(sale);
    setStatusMessage("");
    setEditForm({
      productName: sale.productName,
      description: sale.description,
      price: sale.price,
      discount: sale.discount,
      saleType: sale.saleType,
      playerTarget: sale.playerTarget || "",
      jobTarget: sale.jobTarget || "",
      category: sale.category || "misc",
    });
  }, []);

  const handleSaveEdit = useCallback(async () => {
    if (!editing || isSaving) return;
    setIsSaving(true);
    setStatusMessage("");

    const response = await fetchNui<UpdateSaleResponse>(
      "adminUpdateSale",
      {
        id: editing.id,
        productName: editForm.productName,
        description: editForm.description,
        inventoryItem: editing.inventoryItem,
        quantity: editing.quantity,
        price: editForm.price,
        discount: editForm.discount || "0",
        saleType: editForm.saleType,
        category: editForm.category,
        playerTarget: editForm.saleType === "Person" ? editForm.playerTarget : "",
        jobTarget: editForm.saleType === "Job" ? editForm.jobTarget : "",
      },
      {
        ok: true,
        message: "Sale updated (admin mock).",
        sale: {
          ...editing,
          productName: editForm.productName,
          description: editForm.description,
          price: editForm.price,
          discount: editForm.discount || "0",
          saleType: editForm.saleType,
          category: editForm.category,
          playerTarget: editForm.saleType === "Person" ? editForm.playerTarget : "",
          jobTarget: editForm.saleType === "Job" ? editForm.jobTarget : "",
        },
      },
    ).catch(
      (): UpdateSaleResponse => ({
        ok: false,
        message: "Failed to update sale.",
      }),
    );

    if (!isMountedRef.current) return;
    setIsSaving(false);

    if (!response.ok || !response.sale) {
      setStatusMessage(response.message || "Failed to update sale.");
      return;
    }

    setSales((prev) => prev.map((sale) => (sale.id === editing.id ? response.sale! : sale)));
    setStatusMessage("Sale updated.");
    setEditing(null);
  }, [editForm, editing, isSaving]);

  const handleDelete = useCallback(async (saleId: string) => {
    const response = await fetchNui<DeleteSaleResponse>(
      "adminDeleteSale",
      { id: saleId },
      {
        ok: true,
        message: "Sale deleted (admin mock).",
      },
    ).catch(
      (): DeleteSaleResponse => ({
        ok: false,
        message: "Failed to delete sale.",
      }),
    );

    if (!isMountedRef.current) return;
    if (!response.ok) {
      setStatusMessage(response.message || "Failed to delete sale.");
      return;
    }

    setSales((prev) => prev.filter((sale) => sale.id !== saleId));
    setStatusMessage("Sale deleted.");
  }, []);

  return (
    <section className="flex min-h-0 flex-1 flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
        <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/50 p-3">
          <p className="text-xs text-[var(--ds-text-muted)]">Total Listings</p>
          <p className="mt-1 text-2xl font-semibold text-[var(--ds-text-primary)]">{overviewStats.totalSales}</p>
        </div>
        <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/50 p-3">
          <p className="text-xs text-[var(--ds-text-muted)]">Active Listings</p>
          <p className="mt-1 text-2xl font-semibold text-[var(--ds-text-primary)]">{overviewStats.activeSales}</p>
        </div>
        <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/50 p-3">
          <p className="text-xs text-[var(--ds-text-muted)]">Potential Revenue</p>
          <p className="mt-1 text-2xl font-semibold text-[var(--ds-text-primary)]">
            ${overviewStats.totalRevenue.toFixed(2)}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
        <div className="relative md:col-span-2">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--ds-text-muted)]" />
          <Input
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            placeholder="Search by product, owner, item..."
            className="h-10 pl-9"
          />
        </div>
        <Select
          value={statusFilter}
          onValueChange={(value) => setStatusFilter(value as "all" | "active" | "empty")}
        >
          <SelectTrigger className="h-10">
            <SelectValue placeholder="Status: All" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="active">Active</SelectItem>
            <SelectItem value="empty">Empty</SelectItem>
          </SelectContent>
        </Select>
        <Select
          value={categoryFilter}
          onValueChange={(value) => setCategoryFilter(value as "all" | SaleType)}
        >
          <SelectTrigger className="h-10">
            <SelectValue placeholder="All" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="Public">Public</SelectItem>
            <SelectItem value="Person">Person</SelectItem>
            <SelectItem value="Job">Job</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {statusMessage ? (
        <p className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/60 px-3 py-2 text-xs text-[var(--ds-text-secondary)]">
          {statusMessage}
        </p>
      ) : null}

      <div className="rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/65 p-2">
        <div className="ds-scrollbar h-[520px] w-full overflow-auto rounded-lg bg-[var(--ds-bg-card)]/70">
          <Table>
            <TableHeader className="sticky top-0 z-10 border-b border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/95">
              <TableRow className="hover:bg-transparent">
                <TableHead className="h-11 px-4 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Product</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Item</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Owner</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Qty</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Price</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Discount</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Type</TableHead>
                <TableHead className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Target</TableHead>
                <TableHead className="h-11 px-4 text-right text-xs font-semibold uppercase tracking-wide text-[var(--ds-text-muted)]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {visibleSales.map((sale, index) => (
                <TableRow
                  key={sale.id}
                  className={`h-[58px] border-b border-[var(--ds-border-subtle)]/70 ${
                    index % 2 === 0 ? "bg-[var(--ds-bg-card)]/35" : "bg-transparent"
                  }`}
                >
                  <TableCell className="max-w-[220px] px-4 font-medium text-[var(--ds-text-primary)] truncate">
                    {sale.productName}
                  </TableCell>
                  <TableCell className="px-3 text-[var(--ds-text-secondary)]">{sale.inventoryItem}</TableCell>
                  <TableCell className="px-3 text-[var(--ds-text-secondary)]">
                    {sale.ownerName || sale.owner || "-"}
                  </TableCell>
                  <TableCell className="px-3 font-medium text-[var(--ds-text-primary)]">{sale.quantity}</TableCell>
                  <TableCell className="px-3 font-medium text-[var(--ds-text-primary)]">
                    ${Number(sale.price || 0).toFixed(2)}
                  </TableCell>
                  <TableCell className="px-3 text-[var(--ds-text-secondary)]">{sale.discount}%</TableCell>
                  <TableCell className="px-3">
                    <span
                      className={`inline-flex min-w-[56px] items-center justify-center rounded-full px-2.5 py-1 text-[11px] font-semibold leading-none ${
                        sale.saleType === "Public"
                          ? "bg-sky-500/15 text-sky-300 ring-1 ring-sky-500/30"
                          : sale.saleType === "Person"
                            ? "bg-amber-500/15 text-amber-300 ring-1 ring-amber-500/30"
                            : "bg-emerald-500/15 text-emerald-300 ring-1 ring-emerald-500/30"
                      }`}
                    >
                      {sale.saleType}
                    </span>
                  </TableCell>
                  <TableCell className="max-w-[180px] px-3 truncate text-[var(--ds-text-secondary)]">
                    {sale.saleType === "Person"
                      ? sale.playerTargetName || sale.playerTarget || "-"
                      : sale.saleType === "Job"
                        ? sale.jobTarget || "-"
                        : "-"}
                  </TableCell>
                  <TableCell className="px-4 text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="secondary"
                        className="h-8 w-8 rounded-md border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/70 px-0"
                        onClick={() => handleOpenEdit(sale)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-8 w-8 rounded-md px-0 text-[var(--ds-status-error)] hover:bg-[var(--ds-status-error-soft)] hover:text-[var(--ds-status-error)]"
                        onClick={() => handleDelete(sale.id)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}

              {!isLoading && visibleSales.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={9} className="py-8 text-center text-sm text-[var(--ds-text-secondary)]">
                    No sales found.
                  </TableCell>
                </TableRow>
              ) : null}
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={9} className="py-8 text-center text-sm text-[var(--ds-text-secondary)]">
                    Loading sales...
                  </TableCell>
                </TableRow>
              ) : null}
            </TableBody>
          </Table>
        </div>
      </div>
      <div className="flex items-center justify-between rounded-lg bg-[var(--ds-bg-elevated)]/50 px-3 text-xs text-[var(--ds-text-muted)]">
        <p>
          Showing{" "}
          {totalCount === 0
            ? "0-0"
            : `${(page - 1) * PAGE_SIZE + (visibleSales.length > 0 ? 1 : 0)}-${(page - 1) * PAGE_SIZE + visibleSales.length}`}{" "}
          of {totalCount} listings
        </p>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="rounded px-2 py-1 disabled:opacity-50"
            disabled={page <= 1 || isLoading}
            onClick={() => setPage((prev) => Math.max(1, prev - 1))}
          >
            Prev
          </button>
          <span className="px-2">
            Page {page} / {totalPages}
          </span>
          <button
            type="button"
            className="rounded px-2 py-1 disabled:opacity-50"
            disabled={page >= totalPages || isLoading}
            onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
          >
            Next
          </button>
        </div>
      </div>
      <Dialog open={Boolean(editing)} onOpenChange={(open) => !open && setEditing(null)}>
        <DialogContent className="sm:max-w-[520px]">
          <DialogHeader>
            <DialogTitle>Edit Sale</DialogTitle>
            <DialogDescription>Update selected listing details.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="adminProductName">Product Name</Label>
              <Input
                id="adminProductName"
                value={editForm.productName}
                onChange={(event) =>
                  setEditForm((prev) => ({ ...prev, productName: event.target.value }))
                }
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="adminDescription">Description</Label>
              <Input
                id="adminDescription"
                value={editForm.description}
                onChange={(event) =>
                  setEditForm((prev) => ({ ...prev, description: event.target.value }))
                }
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="adminCategory">Category</Label>
              <Select
                value={editForm.category}
                onValueChange={(value) => setEditForm((prev) => ({ ...prev, category: value }))}
              >
                <SelectTrigger id="adminCategory">
                  <SelectValue placeholder="Category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="misc">Misc</SelectItem>
                  <SelectItem value="weapons">Weapons</SelectItem>
                  <SelectItem value="ammo">Ammo</SelectItem>
                  <SelectItem value="food">Food & Drinks</SelectItem>
                  <SelectItem value="medical">Medical</SelectItem>
                  <SelectItem value="vehicles">Vehicles</SelectItem>
                  <SelectItem value="parts">Vehicle Parts</SelectItem>
                  <SelectItem value="tools">Tools</SelectItem>
                  <SelectItem value="materials">Materials</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="adminPrice">Price</Label>
                <Input
                  id="adminPrice"
                  type="number"
                  value={editForm.price}
                  onChange={(event) =>
                    setEditForm((prev) => ({ ...prev, price: event.target.value }))
                  }
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="adminDiscount">Discount %</Label>
                <Input
                  id="adminDiscount"
                  type="number"
                  value={editForm.discount}
                  onChange={(event) =>
                    setEditForm((prev) => ({ ...prev, discount: event.target.value }))
                  }
                />
              </div>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="adminType">Sale Type</Label>
              <Input
                id="adminType"
                value={editForm.saleType}
                onChange={(event) =>
                  setEditForm((prev) => ({
                    ...prev,
                    saleType:
                      event.target.value === "Person" || event.target.value === "Job"
                        ? event.target.value
                        : "Public",
                  }))
                }
              />
            </div>
            {editForm.saleType === "Person" ? (
              <div className="grid gap-1.5">
                <Label htmlFor="adminPlayerTarget">Player Target</Label>
                <Input
                  id="adminPlayerTarget"
                  value={editForm.playerTarget}
                  onChange={(event) =>
                    setEditForm((prev) => ({ ...prev, playerTarget: event.target.value }))
                  }
                />
              </div>
            ) : null}
            {editForm.saleType === "Job" ? (
              <div className="grid gap-1.5">
                <Label htmlFor="adminJobTarget">Job Target</Label>
                <Input
                  id="adminJobTarget"
                  value={editForm.jobTarget}
                  onChange={(event) =>
                    setEditForm((prev) => ({ ...prev, jobTarget: event.target.value }))
                  }
                />
              </div>
            ) : null}
          </div>
          <DialogFooter>
            <Button type="button" variant="secondary" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button type="button" onClick={handleSaveEdit} disabled={isSaving}>
              {isSaving ? "Saving..." : "Save Changes"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}