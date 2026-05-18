import { MONTH_LABELS } from "./helpers";

type ChartSectionProps = {
  monthlyRevenue: number[];
};

export function ChartSection({ monthlyRevenue }: ChartSectionProps) {
  const maxValue = Math.max(...monthlyRevenue, 0);

  return (
    <div className="xl:col-span-3 rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/70 p-4">
      <div className="mb-4 flex items-center justify-between">
        <p className="text-base font-semibold text-[var(--ds-text-primary)]">Earnings</p>
        <p className="rounded-md border border-[var(--ds-border-subtle)] px-2 py-1 text-xs text-[var(--ds-text-secondary)]">
          This Year
        </p>
      </div>
      <div className="grid h-44 grid-cols-12 items-end gap-2">
        {monthlyRevenue.map((value, index) => {
          const ratio = maxValue > 0 ? Math.max((value / maxValue) * 100, 8) : 0;
          return (
            <div key={MONTH_LABELS[index]} className="flex h-full flex-col justify-end gap-2">
              <div
                className="rounded-md bg-[var(--ds-accent-primary)]/35"
                style={{ height: `${ratio}%`, minHeight: ratio > 0 ? "8px" : "0px" }}
              />
              <p className="text-center text-[10px] text-[var(--ds-text-muted)]">{MONTH_LABELS[index]}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
