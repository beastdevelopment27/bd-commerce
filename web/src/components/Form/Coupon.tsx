import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { fetchNui } from "@/utils/fetchNui";
import { CalendarDays } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

type CouponType = "percent" | "fixed";

type CreateCouponResponse = {
  ok: boolean;
  message: string;
  coupon?: {
    id: number;
    code: string;
    discountType: CouponType;
    discountValue: number;
    maxUses?: number;
    usedCount: number;
    isActive: boolean;
    createdBy: string;
    expiresAt?: string;
  };
};

type CouponListItem = {
  id: number;
  code: string;
  discountType: CouponType;
  discountValue: number;
  maxUses?: number;
  usedCount: number;
  isActive: boolean;
  createdBy: string;
  expiresAt?: string;
};

type CouponListResponse = {
  ok: boolean;
  message: string;
  coupons: CouponListItem[];
};

export default function Coupon() {
  const generatedCodesRef = useRef<Set<string>>(new Set());
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [coupons, setCoupons] = useState<CouponListItem[]>([]);
  const [formData, setFormData] = useState({
    code: "",
    discountType: "percent" as CouponType,
    discountValue: "",
    maxUses: "",
    expiresAt: "",
    isActive: true,
  });
  const generateCouponCode = () => {
    const disallowed = new Set(generatedCodesRef.current);
    if (formData.code.trim()) {
      disallowed.add(formData.code.trim().toUpperCase());
    }

    let nextCode = "";
    let attempts = 0;
    while (attempts < 20) {
      attempts += 1;
      const randomPart = Math.random()
        .toString(36)
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, "")
        .slice(0, 6)
        .padEnd(6, "0");
      const candidate = `BD${randomPart}`;
      if (!disallowed.has(candidate)) {
        nextCode = candidate;
        break;
      }
    }

    if (!nextCode) {
      const fallbackPart = Date.now().toString(36).toUpperCase().slice(-6).padStart(6, "0");
      nextCode = `BD${fallbackPart}`;
    }

    generatedCodesRef.current.add(nextCode);
    setFormData((prev) => ({ ...prev, code: nextCode }));
  };
  const selectedExpiryDate = formData.expiresAt ? new Date(formData.expiresAt) : undefined;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const formattedExpiryDate = selectedExpiryDate
    ? `${String(selectedExpiryDate.getDate()).padStart(2, "0")}/${String(
        selectedExpiryDate.getMonth() + 1,
      ).padStart(2, "0")}/${selectedExpiryDate.getFullYear()}`
    : "";
  const formatCouponExpiry = (rawExpiry?: string) => {
    if (!rawExpiry) return "No expiry";

    const trimmed = String(rawExpiry).trim();
    let parsedDate: Date | null = null;

    if (/^\d+(\.\d+)?$/.test(trimmed)) {
      const numericValue = Number(trimmed);
      if (Number.isFinite(numericValue) && numericValue > 0) {
        const asMs = numericValue > 1000000000000 ? numericValue : numericValue * 1000;
        const dateFromNumber = new Date(asMs);
        if (!Number.isNaN(dateFromNumber.getTime())) {
          parsedDate = dateFromNumber;
        }
      }
    } else {
      const normalized = trimmed.replace(" ", "T");
      const dateFromString = new Date(normalized);
      if (!Number.isNaN(dateFromString.getTime())) {
        parsedDate = dateFromString;
      }
    }

    if (!parsedDate) return "No expiry";
    return `${String(parsedDate.getDate()).padStart(2, "0")}/${String(
      parsedDate.getMonth() + 1,
    ).padStart(2, "0")}/${parsedDate.getFullYear()}`;
  };

  const loadCoupons = useCallback(async () => {
    const response = await fetchNui<CouponListResponse>(
      "getMyCoupons",
      {},
      {
        ok: true,
        message: "Coupons loaded (browser mock).",
        coupons: [],
      },
    ).catch(
      (): CouponListResponse => ({
        ok: false,
        message: "Failed to load coupons.",
        coupons: [],
      }),
    );

    if (!response.ok) return;
    const nextCoupons = Array.isArray(response.coupons) ? response.coupons : [];
    setCoupons(nextCoupons);
  }, []);

  useEffect(() => {
    void loadCoupons();
  }, [loadCoupons]);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (isSubmitting) return;
    setError("");
    setMessage("");

    setIsSubmitting(true);
    const response = await fetchNui<CreateCouponResponse>(
      "createCoupon",
      {
        code: formData.code,
        discountType: formData.discountType,
        discountValue: formData.discountValue,
        maxUses: formData.maxUses === "" ? null : Number(formData.maxUses),
        expiresAt: formData.expiresAt === "" ? null : formData.expiresAt,
        isActive: formData.isActive,
      },
      {
        ok: true,
        message: "Coupon created (browser mock).",
      },
    ).catch(
      (): CreateCouponResponse => ({
        ok: false,
        message: "Failed to create coupon.",
      }),
    );
    setIsSubmitting(false);

    if (!response.ok) {
      setError(response.message || "Failed to create coupon.");
      return;
    }

    setMessage(response.message || "Coupon created.");
    await loadCoupons();
    setFormData({
      code: "",
      discountType: "percent",
      discountValue: "",
      maxUses: "",
      expiresAt: "",
      isActive: true,
    });
  };

  return (
    <section className="min-h-0 flex-1 space-y-4">
      <div className="space-y-0.5">
        <h2 className="text-xl font-semibold text-[var(--ds-text-primary)]">Coupon</h2>
        <p className="text-sm text-[var(--ds-text-secondary)]">
          Create discount coupons and store them in coupon database table.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,560px)_minmax(0,1fr)]">
        <div className="rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/50 p-4">
        <form className="grid gap-3" onSubmit={handleSubmit}>
          <div className="grid gap-1.5">
            <Label htmlFor="couponCode">Coupon Code</Label>
            <div className="flex gap-2">
              <Input
                id="couponCode"
                value={formData.code}
                onChange={(event) =>
                  setFormData((prev) => ({ ...prev, code: event.target.value.toUpperCase() }))
                }
                placeholder="BDXXXXXX"
                required
              />
              <Button type="button" variant="secondary" onClick={generateCouponCode}>
                Generate
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="grid gap-1.5">
              <Label>Discount Type</Label>
              <Select
                value={formData.discountType}
                onValueChange={(value) =>
                  setFormData((prev) => ({
                    ...prev,
                    discountType: value === "fixed" ? "fixed" : "percent",
                  }))
                }
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="percent">Percent (%)</SelectItem>
                  <SelectItem value="fixed">Fixed amount ($)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="discountValue">Discount Value</Label>
              <Input
                id="discountValue"
                type="number"
                min="0"
                step="0.01"
                value={formData.discountValue}
                onChange={(event) =>
                  setFormData((prev) => ({ ...prev, discountValue: event.target.value }))
                }
                placeholder={formData.discountType === "percent" ? "10" : "50"}
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="grid gap-1.5">
              <Label htmlFor="maxUses">Max Uses (optional)</Label>
              <Input
                id="maxUses"
                type="number"
                min="1"
                value={formData.maxUses}
                onChange={(event) =>
                  setFormData((prev) => ({ ...prev, maxUses: event.target.value }))
                }
                placeholder="Leave empty for unlimited"
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="expiresAt">Expiry (optional)</Label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    id="expiresAt"
                    type="button"
                    variant="outline"
                    className="w-full justify-start border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)] text-left font-normal"
                  >
                    <CalendarDays className="h-4 w-4" />
                    {selectedExpiryDate ? formattedExpiryDate : "Pick expiry date"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent
                  className="w-auto rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)] p-2 shadow-xl"
                  align="start"
                >
                  <Calendar
                    mode="single"
                    selected={selectedExpiryDate}
                    disabled={{ before: today }}
                    buttonVariant="secondary"
                    className="rounded-md bg-[var(--ds-bg-card)] p-1"
                    classNames={{
                      weekdays: "grid grid-cols-7 gap-1",
                      week: "mt-1 grid grid-cols-7 gap-1",
                    }}
                    onSelect={(date) =>
                      setFormData((prev) => ({
                        ...prev,
                        expiresAt: date
                          ? `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")} 00:00`
                          : "",
                      }))
                    }
                  />
                </PopoverContent>
              </Popover>
            </div>
          </div>

          <div className="grid gap-1.5">
            <Label>Coupon Status</Label>
            <Select
              value={formData.isActive ? "active" : "inactive"}
              onValueChange={(value) =>
                setFormData((prev) => ({ ...prev, isActive: value === "active" }))
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="inactive">Inactive</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {error ? <p className="text-sm text-[var(--ds-status-error)]">{error}</p> : null}
          {message ? <p className="text-sm text-[var(--ds-status-success)]">{message}</p> : null}

          <div className="flex justify-end">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Creating..." : "Create Coupon"}
            </Button>
          </div>
        </form>
        </div>

        <aside className="flex h-[360px] min-h-0 flex-col rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/50 p-4">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-base font-semibold text-[var(--ds-text-primary)]">Coupon Listing</h3>
            <span className="text-xs text-[var(--ds-text-secondary)]">{coupons.length} total</span>
          </div>

          <div className="ds-scrollbar min-h-0 flex-1 space-y-2 overflow-y-auto pr-1">
            {coupons.length > 0 ? (
              coupons.map((coupon) => {
                const isUsageExhausted =
                  typeof coupon.maxUses === "number" &&
                  coupon.maxUses > 0 &&
                  coupon.usedCount >= coupon.maxUses;
                const statusLabel = !coupon.isActive
                  ? "Inactive"
                  : isUsageExhausted
                    ? "Exhausted"
                    : "Active";
                const statusClassName =
                  statusLabel === "Active"
                    ? "bg-emerald-500/15 text-emerald-300 ring-1 ring-emerald-500/30"
                    : "bg-rose-500/15 text-rose-300 ring-1 ring-rose-500/30";

                return (
                  <div
                    key={coupon.id}
                    className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/70 p-3"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="truncate font-semibold text-[var(--ds-text-primary)]">{coupon.code}</p>
                      <span
                        className={`inline-flex min-w-[78px] items-center justify-center rounded-full px-2.5 py-1 text-[11px] font-semibold leading-none ${statusClassName}`}
                      >
                        {statusLabel}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-[var(--ds-text-secondary)]">
                      {coupon.discountType === "percent"
                        ? `${coupon.discountValue}% OFF`
                        : `$${coupon.discountValue} OFF`}
                      {" • "}
                      Used {coupon.usedCount}
                      {typeof coupon.maxUses === "number" ? `/${coupon.maxUses}` : ""}
                    </p>
                    <p className="mt-1 text-xs text-[var(--ds-text-muted)]">
                      Expiry: {formatCouponExpiry(coupon.expiresAt)}
                    </p>
                  </div>
                );
              })
            ) : (
              <div className="rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/60 px-4 py-8 text-center text-sm text-[var(--ds-text-secondary)]">
                No coupons created yet.
              </div>
            )}
          </div>
        </aside>
      </div>
    </section>
  );
}