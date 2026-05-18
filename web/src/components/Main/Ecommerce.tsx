import { cn } from "@/lib/utils";
import { useVisibility } from "@/providers/VisibilityProvider";
import { fetchNui } from "@/utils/fetchNui";
import { isEnvBrowser } from "@/utils/misc";
import {
  LucideIcon,
  LayoutDashboard,
  ShoppingCart,
  Handshake,
  TicketPercent,
  ShieldCheck,
  Gavel,
  ShieldAlert,
} from "lucide-react";
import {
  NavLink,
  Navigate,
  Outlet,
  Route,
  Routes,
} from "react-router-dom";
import AdminSale from "@/components/Form/AdminSale";
import BuyListing from "@/components/Form/BuyListing";
import DashBoard from "@/components/Form/DashBoard";
import SaleTab from "@/components/Form/SaleTab";
import { EcommercePanelHeader } from "@/components/Main/EcommercePanelHeader";
import Coupon from "../Form/Coupon";
import Auction from "../Form/Auction";
import Reports from "../Form/Reports";

type NavItem =
  | { to: string; icon: LucideIcon }
  | { to: null; icon: LucideIcon };

const SIDEBAR_ITEMS: NavItem[] = [
  { to: "/dashboard", icon: LayoutDashboard },
  { to: "/buy-listing", icon: ShoppingCart },
  { to: "/sale-tab", icon: Handshake },
  { to: "/coupen-code", icon: TicketPercent },
  { to: "/admin-sale", icon: ShieldCheck },
  { to: "/reports", icon: ShieldAlert },
  { to: "/auction", icon: Gavel },
];

function navItemClassName(isActive: boolean) {
  return cn(
    "relative flex w-full items-center justify-center py-1.5 transition-colors",
    isActive ? "text-[var(--ds-accent-primary)]" : "text-[var(--ds-text-muted)]",
  );
}

function navIconWrapClassName(isActive: boolean) {
  return cn(
    "flex h-10 w-10 items-center justify-center rounded-lg transition-colors",
    isActive
      ? "bg-[var(--ds-sidebar-active-bg)] text-[var(--ds-sidebar-active-icon)]"
      : "hover:bg-[var(--ds-sidebar-hover-bg)] hover:text-[var(--ds-sidebar-hover-text)]",
  );
}

function EcommerceShell() {
  const { setVisible } = useVisibility();

  const handleClose = () => {
    if (!isEnvBrowser()) void fetchNui("hideFrame");
    else setVisible(false);
  };

  return (
    <div className="flex h-full w-full items-center justify-center p-4">
      <div
        className="flex overflow-hidden rounded-xl border border-[var(--ds-border-default)] bg-[var(--ds-bg-card)] shadow-[var(--ds-card-shadow)] md:w-[70%]"
        style={{ width: "1375px", height: "835px" }}
      >
        <nav
          className={cn(
            "flex h-full w-16 shrink-0 flex-col items-stretch border-r border-[var(--ds-border-default)]",
            "bg-[var(--ds-bg-sidebar)] py-4",
          )}
          aria-label="Primary"
        >
          <div className="mt-1 flex flex-col gap-1">
            {SIDEBAR_ITEMS.map((item, index) => {
              const Icon = item.icon;
              if (item.to === null) {
                return (
                  <div
                    key={`spacer-${index}`}
                    className="flex w-full justify-center py-1.5 opacity-35"
                    aria-hidden
                  >
                    <div
                      className={cn(
                        "flex h-10 w-10 items-center justify-center rounded-lg",
                        "text-[var(--ds-text-disabled)]",
                      )}
                    >
                      <Icon className="h-5 w-5" strokeWidth={1.75} />
                    </div>
                  </div>
                );
              }
              return (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.to === "/dashboard"}
                  className={({ isActive }) => navItemClassName(isActive)}
                >
                  {({ isActive }) => (
                    <>
                      {isActive ? (
                        <span
                          className={cn(
                            "pointer-events-none absolute left-0 top-1/2 z-10 h-9 w-0.5",
                            "-translate-y-1/2 rounded-r bg-[var(--ds-accent-primary)]",
                          )}
                          aria-hidden
                        />
                      ) : null}
                      <span className={navIconWrapClassName(isActive)}>
                        <Icon className="h-5 w-5" strokeWidth={1.75} />
                      </span>
                    </>
                  )}
                </NavLink>
              );
            })}
          </div>
        </nav>

        <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden">
          <EcommercePanelHeader onClose={handleClose} />
          <div
            className={cn(
              "flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden",
              "bg-[var(--ds-bg-main)] px-5 py-4",
            )}
          >
            <Outlet />
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Ecommerce() {
  return (
    <Routes>
      <Route path="/" element={<EcommerceShell />}>
        <Route index element={<Navigate to="/buy-listing" replace />} />
        <Route path="dashboard" element={<DashBoard />} />
        <Route path="buy-listing" element={<BuyListing />} />
        <Route path="admin-sale" element={<AdminSale />} />
        <Route path="sale-tab" element={<SaleTab />} />
        <Route path="coupen-code" element={<Coupon />} />
        <Route path="auction" element={<Auction />} />
        <Route path="reports" element={<Reports />} />
        <Route path="*" element={<Navigate to="/buy-listing" replace />} />
      </Route>
    </Routes>
  );
}
