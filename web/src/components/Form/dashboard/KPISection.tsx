import type { KpiCard } from "./types";

type KPISectionProps = {
  cards: KpiCard[];
  loading: boolean;
};

export function KPISection({ cards, loading }: KPISectionProps) {
  return (
    <div className="overflow-hidden rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/65">
      <div className="grid grid-cols-1 divide-y divide-[var(--ds-border-subtle)] sm:grid-cols-2 sm:divide-x sm:divide-y-0 xl:grid-cols-4">
        {cards.map((card) => {
          const Icon = card.icon;
          return (
            <div key={card.id} className="flex items-start gap-3 p-4">
              <div className="mt-0.5 rounded-md border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-card)]/70 p-2">
                <Icon className="h-4 w-4 text-[var(--ds-text-secondary)]" />
              </div>
              <div>
                <p className="text-[11px] leading-4 text-[var(--ds-text-muted)]">{card.label}</p>
                <p className="mt-1 text-xl font-semibold leading-none text-[var(--ds-text-primary)]">
                  {loading ? "..." : card.value}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
