import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { cn } from "@/lib/utils";
import { claimsMockData } from "@/mocks/claimsMockData";
import { fetchNui } from "@/utils/fetchNui";
import { ITEM_IMAGE_PLACEHOLDER } from "@/lib/commerceConfig";
import { getImageUrl } from "@/utils/misc";
import { PackageCheck, RefreshCw } from "lucide-react";
import { useCallback, useEffect, useState } from "react";

type ClaimItem = {
  id: string;
  claimType: string;
  claimTypeLabel: string;
  inventoryItem: string;
  quantity: number;
  productName: string;
  saleId?: string | null;
  sourceNote?: string;
  createdAt?: string | null;
};

type ClaimsResponse = {
  ok: boolean;
  message: string;
  claims: ClaimItem[];
};

type ClaimActionResponse = {
  ok: boolean;
  message: string;
};

export default function Claims() {
  const [claims, setClaims] = useState<ClaimItem[]>([]);
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [claimingId, setClaimingId] = useState<string | null>(null);

  const loadClaims = useCallback(async () => {
    setIsLoading(true);
    setMessage("");
    const response = await fetchNui<ClaimsResponse>(
      "getPendingClaims",
      {},
      {
        ok: true,
        message: "Loaded mock claims.",
        claims: claimsMockData,
      },
    ).catch(
      (): ClaimsResponse => ({
        ok: false,
        message: "Failed to load claims.",
        claims: [],
      }),
    );
    setIsLoading(false);
    if (!response.ok) {
      setClaims([]);
      setMessage(response.message || "Failed to load claims.");
      return;
    }
    setClaims(Array.isArray(response.claims) ? response.claims : []);
    if ((response.claims || []).length === 0) {
      setMessage("No pending claims. Items appear here when you win an auction, a listing is removed, or an auction ends with no bids.");
    }
  }, []);

  useEffect(() => {
    void loadClaims();
  }, [loadClaims]);

  const handleClaim = async (claim: ClaimItem) => {
    if (claimingId) return;
    setClaimingId(claim.id);
    setMessage("");
    const response = await fetchNui<ClaimActionResponse>(
      "claimCommerceItem",
      { id: claim.id },
      {
        ok: true,
        message: `Claimed ${claim.quantity}x ${claim.productName} (browser mock).`,
      },
    ).catch(
      (): ClaimActionResponse => ({
        ok: false,
        message: "Failed to claim item.",
      }),
    );
    setClaimingId(null);
    if (!response.ok) {
      setMessage(response.message || "Failed to claim item.");
      return;
    }
    setMessage(response.message || "Item claimed successfully.");
    setClaims((prev) => prev.filter((entry) => entry.id !== claim.id));
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-4">
      <div className="flex shrink-0 items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[var(--ds-text-primary)]">Claims</h2>
          <p className="mt-1 text-sm text-[var(--ds-text-secondary)]">
            Collect items from ended auctions or returned listing stock.
          </p>
        </div>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="border-[var(--ds-border-subtle)]"
          onClick={() => void loadClaims()}
          disabled={isLoading}
        >
          <RefreshCw className={cn("mr-2 h-4 w-4", isLoading && "animate-spin")} />
          Refresh
        </Button>
      </div>

      {message ? (
        <p
          className={cn(
            "shrink-0 rounded-md border px-3 py-2 text-sm",
            message.toLowerCase().includes("success") || message.toLowerCase().includes("claimed")
              ? "border-[var(--ds-accent-primary)]/40 bg-[var(--ds-accent-primary)]/10 text-[var(--ds-text-primary)]"
              : "border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)] text-[var(--ds-text-secondary)]",
          )}
        >
          {message}
        </p>
      ) : null}

      <div className="min-h-0 flex-1 overflow-auto rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]">
        <Table>
          <TableHeader>
            <TableRow className="border-[var(--ds-border-subtle)] hover:bg-transparent">
              <TableHead className="text-[var(--ds-text-muted)]">Item</TableHead>
              <TableHead className="text-[var(--ds-text-muted)]">Reason</TableHead>
              <TableHead className="text-[var(--ds-text-muted)]">Qty</TableHead>
              <TableHead className="text-[var(--ds-text-muted)]">Note</TableHead>
              <TableHead className="text-right text-[var(--ds-text-muted)]">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={5} className="py-10 text-center text-[var(--ds-text-muted)]">
                  Loading claims…
                </TableCell>
              </TableRow>
            ) : claims.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="py-10 text-center text-[var(--ds-text-muted)]">
                  Nothing to claim right now.
                </TableCell>
              </TableRow>
            ) : (
              claims.map((claim) => (
                <TableRow key={claim.id} className="border-[var(--ds-border-subtle)]">
                  <TableCell>
                    <div className="flex items-center gap-3">
                      <img
                        src={getImageUrl(
                          `${claim.inventoryItem}.png`,
                          undefined,
                          ITEM_IMAGE_PLACEHOLDER,
                        )}
                        alt=""
                        className="h-10 w-10 rounded-md border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-main)] object-contain p-1"
                      />
                      <div>
                        <p className="font-medium text-[var(--ds-text-primary)]">{claim.productName}</p>
                        <p className="text-xs text-[var(--ds-text-muted)]">{claim.inventoryItem}</p>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-[var(--ds-text-secondary)]">{claim.claimTypeLabel}</TableCell>
                  <TableCell className="text-[var(--ds-text-primary)]">{claim.quantity}</TableCell>
                  <TableCell className="max-w-[200px] truncate text-xs text-[var(--ds-text-muted)]">
                    {claim.sourceNote || "—"}
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      type="button"
                      size="sm"
                      className="bg-[var(--ds-accent-primary)] text-white hover:opacity-90"
                      disabled={claimingId === claim.id}
                      onClick={() => void handleClaim(claim)}
                    >
                      <PackageCheck className="mr-1.5 h-4 w-4" />
                      {claimingId === claim.id ? "Claiming…" : "Claim"}
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
