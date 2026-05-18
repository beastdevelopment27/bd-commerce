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
import { Wallet } from "lucide-react";
import type { SellerWalletData } from "./types";

type TopBarProps = {
  wallet: SellerWalletData | null;
  withdrawDialogOpen: boolean;
  setWithdrawDialogOpen: (open: boolean) => void;
  withdrawAmount: string;
  setWithdrawAmount: (value: string) => void;
  isLoadingWallet: boolean;
  isWithdrawing: boolean;
  onWithdraw: () => void;
};

export function TopBar({
  wallet,
  withdrawDialogOpen,
  setWithdrawDialogOpen,
  withdrawAmount,
  setWithdrawAmount,
  isLoadingWallet,
  isWithdrawing,
  onWithdraw,
}: TopBarProps) {
  const walletCards = [
    { id: "wallet", label: "Wallet", value: `$${Number(wallet?.balance || 0).toFixed(2)}` },
    { id: "total-sales", label: "Total Sales", value: String(wallet?.totalSales || 0) },
    { id: "revenue", label: "Revenue", value: `$${Number(wallet?.totalRevenue || 0).toFixed(2)}` },
  ];

  return (
    <div className="flex items-start justify-between gap-4">
      <div className="space-y-0.5">
        <h1 className="text-xl font-semibold leading-tight text-[var(--ds-text-primary)]">Sales</h1>
        <p className="text-sm text-[var(--ds-text-secondary)]">Create and manage sale listings</p>
      </div>

      <div className="flex w-full max-w-[860px] items-center justify-end gap-3 rounded-xl bg-[var(--ds-bg-elevated)]/35 p-1.5">
        <div className="grid grid-cols-3 gap-2">
          {walletCards.map((card) => (
            <div
              key={card.id}
              className="min-w-[82px] rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/55 px-2.5 py-1.5"
            >
              <p className="text-[9px] uppercase tracking-wide text-[var(--ds-text-muted)]">
                {card.label}
              </p>
              <p className="text-[12px] font-semibold leading-tight text-[var(--ds-text-primary)]">
                {card.value}
              </p>
            </div>
          ))}
        </div>

        <Dialog open={withdrawDialogOpen} onOpenChange={setWithdrawDialogOpen}>
          <DialogTrigger asChild>
            <Button
              type="button"
              variant="secondary"
              className="h-[42px] rounded-lg px-4 text-sm font-semibold"
              disabled={isLoadingWallet || Number(wallet?.balance || 0) <= 0}
            >
              <Wallet className="h-3.5 w-3.5" />
              Withdraw (Cash)
            </Button>
          </DialogTrigger>
          <DialogContent className="duration-0 data-[state=closed]:animate-none data-[state=open]:animate-none sm:max-w-[420px]">
            <DialogHeader>
              <DialogTitle>Withdraw Earnings</DialogTitle>
              <DialogDescription>Withdraw available seller wallet balance to cash only.</DialogDescription>
            </DialogHeader>
            <div className="grid gap-2">
              <Label htmlFor="withdrawAmount">Amount</Label>
              <Input
                id="withdrawAmount"
                type="number"
                min="0.01"
                step="0.01"
                placeholder="0.00"
                value={withdrawAmount}
                onChange={(event) => setWithdrawAmount(event.target.value)}
              />
              <p className="text-xs text-[var(--ds-text-muted)]">
                Available: ${Number(wallet?.balance || 0).toFixed(2)}
              </p>
            </div>
            <DialogFooter>
              <Button
                type="button"
                variant="secondary"
                onClick={() => setWithdrawDialogOpen(false)}
                disabled={isWithdrawing}
              >
                Cancel
              </Button>
              <Button type="button" onClick={onWithdraw} disabled={isWithdrawing}>
                {isWithdrawing ? "Withdrawing..." : "Withdraw To Cash"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}
