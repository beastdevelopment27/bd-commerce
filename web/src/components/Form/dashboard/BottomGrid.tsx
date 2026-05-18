import type { DashboardLatestListing, DashboardPerformanceItem } from "./types";

type BottomGridProps = {
  latestListings: DashboardLatestListing[];
  performance: DashboardPerformanceItem[];
  currencyFormatter: Intl.NumberFormat;
};

export function BottomGrid({ latestListings, performance, currencyFormatter }: BottomGridProps) {
  const total = Math.max(
    performance.reduce((sum, segment) => sum + segment.value, 0),
    1,
  );

  return (
    <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
      <div className="rounded-xl bg-[var(--ds-bg-elevated)]/70 p-3 xl:min-h-[190px]">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-base font-semibold text-[var(--ds-text-primary)]">Latest Listings</p>
          <span className="rounded-md border border-[var(--ds-border-subtle)] px-2 py-1 text-[11px] text-[var(--ds-text-secondary)]">
            Latest 3
          </span>
        </div>
        <div className="overflow-hidden rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/35">
          {latestListings.length == 0 ? (
            <div className="px-3 py-5 text-sm text-[var(--ds-text-muted)]">No listings yet.</div>
          ) : (
            latestListings.map((item, index) => (
              <div
                key={item.id}
                className={`flex items-center justify-between px-3 py-2 transition-colors hover:bg-[var(--ds-bg-card)]/50 ${
                  index > 0 ? "border-t border-[var(--ds-border-subtle)]" : ""
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-8 w-8 items-center justify-center rounded-md border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/90 text-xs font-semibold text-[var(--ds-text-primary)]">
                    {(item.productName || item.inventoryItem || "?").charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-[var(--ds-text-primary)]">
                      {item.productName || item.inventoryItem || "Unknown"}
                    </p>
                    <p className="text-xs text-[var(--ds-text-muted)]">
                      Qty: {Number(item.quantity) || 0} - {item.saleType}
                    </p>
                  </div>
                </div>
                <p className="text-sm font-semibold text-[var(--ds-text-primary)]">
                  ${currencyFormatter.format(item.unitPrice)}
                </p>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="rounded-xl bg-[var(--ds-bg-elevated)]/70 p-4 xl:min-h-[190px]">
        <div className="mb-3 flex items-center justify-between">
          <p className="text-base font-semibold text-[var(--ds-text-primary)]">Performance Snapshot</p>
          <span className="rounded-md border border-[var(--ds-border-subtle)] px-2 py-1 text-[11px] text-[var(--ds-text-secondary)]">
            Live Split
          </span>
        </div>
        <div className="overflow-hidden rounded-lg border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/55">
          <div className="grid grid-cols-3 bg-[var(--ds-bg-card)]/80 px-3 py-2 text-xs font-medium text-[var(--ds-text-secondary)]">
            <p>Type</p>
            <p className="text-right">Count</p>
            <p className="text-right">Share</p>
          </div>
          {performance.map((segment) => {
            const percent = Math.round((segment.value / total) * 100);
            return (
              <div
                key={segment.label}
                className="grid grid-cols-3 border-t border-[var(--ds-border-subtle)] px-3 py-2 text-sm text-[var(--ds-text-primary)] transition-colors hover:bg-[var(--ds-bg-card)]/45"
              >
                <p>{segment.label}</p>
                <p className="text-right">{segment.value}</p>
                <p className="text-right">{percent}%</p>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
