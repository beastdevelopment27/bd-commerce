import type { LucideIcon } from "lucide-react";

export type SaleType = "Public" | "Person" | "Job";

export type SellerWalletData = {
  ownerIdentifier: string;
  balance: number;
  totalSales: number;
  totalRevenue: number;
  totalWithdrawn: number;
};

export type DashboardLatestListing = {
  id: string;
  productName: string;
  inventoryItem: string;
  quantity: string;
  price: string;
  discount: string;
  saleType: SaleType;
  unitPrice: number;
};

export type DashboardPerformanceItem = {
  label: SaleType;
  value: number;
};

export type DashboardOverviewResponse = {
  ok: boolean;
  message: string;
  wallet?: SellerWalletData;
  taxPercent?: number;
  kpi?: {
    totalListings: number;
    totalUnits: number;
    totalValue: number;
    discountedListings: number;
  };
  monthlyRevenue?: number[];
  performance?: DashboardPerformanceItem[];
  latestListings?: DashboardLatestListing[];
};

export type WithdrawSellerEarningsResponse = {
  ok: boolean;
  message: string;
  wallet?: SellerWalletData;
};

export type KpiCard = {
  id: string;
  label: string;
  value: string;
  icon: LucideIcon;
};
