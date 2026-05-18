import * as React from "react"

import { cn } from "@/lib/utils"

const Input = React.forwardRef<HTMLInputElement, React.ComponentProps<"input">>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          "flex h-9 w-full rounded-[var(--ds-radius-md)] border border-[var(--ds-input-border)] bg-[var(--ds-input-bg)] px-3 py-1 text-base text-[var(--ds-input-text)] shadow-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-[var(--ds-input-placeholder)] hover:border-[var(--ds-input-hover-border)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ds-accent-primary)] focus-visible:border-[var(--ds-input-focus-border)] focus-visible:shadow-[0_0_0_3px_var(--ds-input-focus-glow)] disabled:bg-[var(--ds-input-disabled-bg)] disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Input.displayName = "Input"

export { Input }
