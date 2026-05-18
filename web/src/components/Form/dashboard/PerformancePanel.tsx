import type { DashboardPerformanceItem } from "./types";

const SEGMENT_COLORS = ["#6ea8fe", "#4ade80", "#facc15"];

type PerformancePanelProps = {
  performance: DashboardPerformanceItem[];
};

export function PerformancePanel({ performance }: PerformancePanelProps) {
  const total = Math.max(
    performance.reduce((sum, segment) => sum + segment.value, 0),
    1,
  );

  let current = 0;
  const segments = performance.map((segment, index) => {
    const percent = Math.round((segment.value / total) * 100);
    const start = current;
    current += percent;
    return {
      ...segment,
      percent,
      color: SEGMENT_COLORS[index] || "#6ea8fe",
      range: `${SEGMENT_COLORS[index] || "#6ea8fe"} ${start}% ${current}%`,
    };
  });

  const donutGradient = `conic-gradient(${segments.map((segment) => segment.range).join(", ")})`;

  return (
    <div className="xl:col-span-2 rounded-xl border border-[var(--ds-border-subtle)] bg-[var(--ds-bg-elevated)]/70 p-4">
      <div className="mb-4 flex items-center justify-between">
        <p className="text-base font-semibold text-[var(--ds-text-primary)]">Listing Type Performance</p>
        <p className="rounded-md border border-[var(--ds-border-subtle)] px-2 py-1 text-xs text-[var(--ds-text-secondary)]">
          All Time
        </p>
      </div>
      <div className="flex flex-col items-center gap-4 py-2">
        <div className="relative h-28 w-28 rounded-full" style={{ background: donutGradient }}>
          <div className="absolute inset-[22px] rounded-full bg-[var(--ds-bg-card)]" />
        </div>
        <div className="grid w-full grid-cols-1 gap-2 sm:grid-cols-3">
          {segments.map((segment) => (
            <div key={segment.label} className="flex items-center gap-2 text-xs text-[var(--ds-text-secondary)]">
              <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: segment.color }} />
              <span>
                {segment.label} ({segment.percent}%)
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
