import {
  getCommercePanelSubtitle,
  getCommercePanelTitle,
} from "@/lib/commerceConfig";
import { cn } from "@/lib/utils";
import { FileText, X } from "lucide-react";

type EcommercePanelHeaderProps = {
  onClose: () => void;
};

/** Full-width top bar: branding (RTO) + close — slightly lighter than main body. */
export function EcommercePanelHeader({ onClose }: EcommercePanelHeaderProps) {
  return (
    <header
      className={cn(
        "flex shrink-0 items-center justify-between",
        "border-b border-[var(--ds-border-default)] bg-[var(--ds-bg-elevated)] px-5 py-4 sm:px-7",
      )}
    >
      <div className="flex items-center gap-3.5">
        <div
          className={cn(
            "flex h-11 w-11 shrink-0 items-center justify-center rounded-[10px]",
            "bg-[var(--ds-bg-main)]",
          )}
          aria-hidden
        >
          <FileText
            className="h-[22px] w-[22px] text-[var(--ds-accent-primary)]"
            strokeWidth={2}
          />
        </div>
        <div className="flex flex-col justify-center gap-0.5">
          <h1
            className={cn(
              "text-lg font-bold leading-tight tracking-tight text-[var(--ds-text-primary)]",
            )}
          >
            {getCommercePanelTitle()}
          </h1>
          <p className="text-sm font-normal leading-tight text-[var(--ds-text-secondary)]">
            {getCommercePanelSubtitle()}
          </p>
        </div>
      </div>

      <div className="flex flex-col items-end justify-center gap-1">
        <span className="text-[11px] font-normal text-[var(--ds-text-secondary)]">
          Close
        </span>
        <button
          type="button"
          onClick={onClose}
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-full",
            "border border-[var(--ds-border-default)] bg-[var(--ds-btn-secondary-bg)] text-[var(--ds-btn-secondary-text)]",
            "transition-colors hover:border-[var(--ds-border-strong)] hover:bg-[var(--ds-btn-secondary-hover)]",
          )}
          aria-label="Close"
        >
          <X className="h-4 w-4" strokeWidth={1.5} />
        </button>
      </div>
    </header>
  );
}
