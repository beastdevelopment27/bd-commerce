import { fetchNui } from "@/utils/fetchNui";
import { Banknote, ClipboardList, CircleDollarSign, Users, Wallet } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { BottomGrid } from "./dashboard/BottomGrid";
import { ChartSection } from "./dashboard/ChartSection";
import { KPISection } from "./dashboard/KPISection";
import { PerformancePanel } from "./dashboard/PerformancePanel";
import { TopBar } from "./dashboard/TopBar";
import { getDiscountedPrice, toMoney } from "./dashboard/helpers";
import type {
  DashboardLatestListing,
  DashboardOverviewResponse,
  DashboardPerformanceItem,
  KpiCard,
  SellerWalletData,
  WithdrawSellerEarningsResponse,
} from "./dashboard/types";

export default function DashBoard() {
  const lastOverviewFetchAtRef = useRef(0);
  const [loading, setLoading] = useState(false);
  const [isLoadingWallet, setIsLoadingWallet] = useState(false);
  const [isWithdrawing, setIsWithdrawing] = useState(false);
  const [wallet, setWallet] = useState<SellerWalletData | null>(null);
  const [withdrawDialogOpen, setWithdrawDialogOpen] = useState(false);
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [monthlyRevenue, setMonthlyRevenue] = useState<number[]>(Array.from({ length: 12 }, () => 0));
  const [performance, setPerformance] = useState<DashboardPerformanceItem[]>([
    { label: "Public", value: 0 },
    { label: "Person", value: 0 },
    { label: "Job", value: 0 },
  ]);
  const [latestListings, setLatestListings] = useState<DashboardLatestListing[]>([]);
  const [kpi, setKpi] = useState({
    totalListings: 0,
    totalUnits: 0,
    totalValue: 0,
    discountedListings: 0,
  });

  const currencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat("en-US", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }),
    [],
  );

  const loadOverview = useCallback(async (force = false) => {
    const now = Date.now();
    if (!force && now - lastOverviewFetchAtRef.current < 10000) {
      return;
    }
    lastOverviewFetchAtRef.current = now;

    setLoading(true);
    setIsLoadingWallet(true);
    const response = await fetchNui<DashboardOverviewResponse>(
      "getDashboardOverview",
      {},
      {
        ok: true,
        message: "Dashboard overview mock.",
        wallet: {
          ownerIdentifier: "mock-owner",
          balance: 4200,
          totalSales: 12,
          totalRevenue: 5600,
          totalWithdrawn: 1400,
        },
        kpi: {
          totalListings: 3,
          totalUnits: 3,
          totalValue: 32,
          discountedListings: 1,
        },
        monthlyRevenue: [2, 3, 3, 4, 4, 4, 2, 3, 4, 5, 4, 6],
        performance: [
          { label: "Public", value: 11 },
          { label: "Person", value: 1 },
          { label: "Job", value: 1 },
        ],
        latestListings: [
          {
            id: "sale-3",
            productName: "Bullet 3",
            inventoryItem: "ammo-9",
            quantity: "1",
            price: "12",
            discount: "0",
            saleType: "Public",
            unitPrice: 12,
          },
          {
            id: "sale-2",
            productName: "Bullet 2",
            inventoryItem: "ammo-9",
            quantity: "1",
            price: "10",
            discount: "0",
            saleType: "Public",
            unitPrice: 10,
          },
          {
            id: "sale-1",
            productName: "Bullet 1",
            inventoryItem: "ammo-9",
            quantity: "1",
            price: "10",
            discount: "0",
            saleType: "Public",
            unitPrice: 10,
          },
        ],
      },
    ).catch(
      (): DashboardOverviewResponse => ({
        ok: false,
        message: "Failed to load dashboard overview.",
      }),
    );
    setLoading(false);
    setIsLoadingWallet(false);
    if (!response.ok) return;

    setWallet(response.wallet || null);
    setKpi(
      response.kpi || {
        totalListings: 0,
        totalUnits: 0,
        totalValue: 0,
        discountedListings: 0,
      },
    );
    setMonthlyRevenue(
      Array.from({ length: 12 }, (_, idx) => Number(response.monthlyRevenue?.[idx] || 0)),
    );
    setPerformance(
      response.performance || [
        { label: "Public", value: 0 },
        { label: "Person", value: 0 },
        { label: "Job", value: 0 },
      ],
    );
    setLatestListings(
      (response.latestListings || []).map((listing) => ({
        ...listing,
        unitPrice: Number.isFinite(listing.unitPrice)
          ? listing.unitPrice
          : getDiscountedPrice(Number(listing.price) || 0, Number(listing.discount) || 0),
      })),
    );
  }, []);

  useEffect(() => {
    loadOverview(true);
  }, [loadOverview]);

  const handleWithdrawEarnings = useCallback(async () => {
    if (isWithdrawing) return;
    const amount = Number(withdrawAmount);
    if (!Number.isFinite(amount) || amount <= 0) return;

    setIsWithdrawing(true);
    const response = await fetchNui<WithdrawSellerEarningsResponse>(
      "withdrawSellerEarnings",
      { amount },
      {
        ok: true,
        message: "Withdrew to cash (browser mock).",
        wallet: {
          ownerIdentifier: wallet?.ownerIdentifier || "mock-owner",
          balance: Math.max((wallet?.balance || 0) - amount, 0),
          totalSales: wallet?.totalSales || 0,
          totalRevenue: wallet?.totalRevenue || 0,
          totalWithdrawn: (wallet?.totalWithdrawn || 0) + amount,
        },
      },
    ).catch(
      (): WithdrawSellerEarningsResponse => ({
        ok: false,
        message: "Failed to withdraw earnings.",
      }),
    );
    setIsWithdrawing(false);

    if (!response.ok) return;
    if (response.wallet) setWallet(response.wallet);
    setWithdrawAmount("");
    setWithdrawDialogOpen(false);
    loadOverview(true);
  }, [isWithdrawing, loadOverview, wallet, withdrawAmount]);

  const performanceMap = useMemo(() => {
    return performance.reduce<Record<string, number>>((acc, item) => {
      acc[item.label] = item.value;
      return acc;
    }, {});
  }, [performance]);

  const avgUnitPrice = useMemo(() => {
    const totalUnits = latestListings.reduce((sum, listing) => sum + (Number(listing.quantity) || 0), 0);
    if (totalUnits <= 0) return 0;
    const total = latestListings.reduce(
      (sum, listing) => sum + (Number(listing.quantity) || 0) * (Number(listing.unitPrice) || 0),
      0,
    );
    return total / totalUnits;
  }, [latestListings]);

  const kpiCards: KpiCard[] = useMemo(
    () => [
      { id: "active", label: "Active Listings", value: String(kpi.totalListings), icon: ClipboardList },
      { id: "units", label: "Listed Units", value: String(kpi.totalUnits), icon: Banknote },
      { id: "discounted", label: "Discounted Listings", value: String(kpi.discountedListings), icon: CircleDollarSign },
      { id: "public", label: "Public Listings", value: String(performanceMap.Public || 0), icon: Users },
      { id: "person", label: "Person Listings", value: String(performanceMap.Person || 0), icon: Users },
      { id: "job", label: "Job Listings", value: String(performanceMap.Job || 0), icon: Users },
      { id: "avg-price", label: "Avg Unit Price", value: toMoney(avgUnitPrice, currencyFormatter), icon: Banknote },
      { id: "total-value", label: "Total Value", value: toMoney(kpi.totalValue, currencyFormatter), icon: Wallet },
    ],
    [avgUnitPrice, currencyFormatter, kpi.discountedListings, kpi.totalListings, kpi.totalUnits, kpi.totalValue, performanceMap.Job, performanceMap.Person, performanceMap.Public],
  );

  return (
    <div className="min-h-0 flex-1 space-y-4">
      <TopBar
        wallet={wallet}
        withdrawDialogOpen={withdrawDialogOpen}
        setWithdrawDialogOpen={setWithdrawDialogOpen}
        withdrawAmount={withdrawAmount}
        setWithdrawAmount={setWithdrawAmount}
        isLoadingWallet={isLoadingWallet}
        isWithdrawing={isWithdrawing}
        onWithdraw={handleWithdrawEarnings}
      />

      <KPISection cards={kpiCards} loading={loading} />

      <div className="grid grid-cols-1 gap-3 xl:grid-cols-5">
        <ChartSection monthlyRevenue={monthlyRevenue} />
        <PerformancePanel performance={performance} />
      </div>

      <BottomGrid latestListings={latestListings} performance={performance} currencyFormatter={currencyFormatter} />
    </div>
  );
}
