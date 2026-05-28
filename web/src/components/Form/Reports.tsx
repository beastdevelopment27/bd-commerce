import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { fetchNui } from "@/utils/fetchNui";
import { useCallback, useEffect, useMemo, useState } from "react";

type ReportStatus = "pending" | "reviewed" | "resolved";
type ReportReason = "Scam" | "Wrong Price" | "Abuse";

type ReportItem = {
  id: number;
  listingId: number;
  listingTitle: string;
  listingPrice: number;
  sellerId: string;
  sellerName?: string;
  reporterId: string;
  reporterName?: string;
  reason: ReportReason;
  description: string;
  status: ReportStatus;
  createdAt?: string;
};

type ReportsResponse = {
  ok: boolean;
  message: string;
  reports: ReportItem[];
  total: number;
  page: number;
  pageSize: number;
};

type ModerateResponse = {
  ok: boolean;
  message: string;
};

const PAGE_SIZE = 20;

type ModerationAction = "resolve" | "remove_listing" | "ban_seller";

type PendingModeration = {
  reportId: number;
  action: "remove_listing" | "ban_seller";
};

const MODERATION_CONFIRM: Record<
  PendingModeration["action"],
  { title: string; description: string; confirmLabel: string }
> = {
  remove_listing: {
    title: "Remove listing",
    description:
      "Remove this listing from the marketplace? The seller can collect their items on the Claims page.",
    confirmLabel: "Remove listing",
  },
  ban_seller: {
    title: "Ban seller",
    description:
      "Ban this seller from the marketplace? They will not be able to create new listings.",
    confirmLabel: "Ban seller",
  },
};

export default function Reports() {
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [statusFilter, setStatusFilter] = useState<"all" | ReportStatus>("pending");
  const [reasonFilter, setReasonFilter] = useState<"all" | ReportReason>("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [pendingModeration, setPendingModeration] = useState<PendingModeration | null>(null);

  const loadReports = useCallback(async () => {
    setIsLoading(true);
    const response = await fetchNui<ReportsResponse>(
      "getReports",
      {
        status: statusFilter,
        reason: reasonFilter,
        page,
        pageSize: PAGE_SIZE,
      },
      {
        ok: true,
        message: "Loaded mock reports.",
        reports: [],
        total: 0,
        page,
        pageSize: PAGE_SIZE,
      },
    ).catch(
      (): ReportsResponse => ({
        ok: false,
        message: "Failed to load reports.",
        reports: [],
        total: 0,
        page,
        pageSize: PAGE_SIZE,
      }),
    );
    setIsLoading(false);
    if (!response.ok) {
      setReports([]);
      setTotal(0);
      setMessage(response.message || "Failed to load reports.");
      return;
    }
    setReports(response.reports || []);
    setTotal(response.total || 0);
    setMessage("");
  }, [page, reasonFilter, statusFilter]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  const filtered = useMemo(() => {
    const needle = searchTerm.trim().toLowerCase();
    if (!needle) return reports;
    return reports.filter((r) =>
      [
        r.listingTitle,
        r.reason,
        r.description,
        r.sellerName || r.sellerId,
        r.reporterName || r.reporterId,
      ]
        .join(" ")
        .toLowerCase()
        .includes(needle),
    );
  }, [reports, searchTerm]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const runAction = useCallback(
    async (reportId: number, action: ModerationAction) => {
      const response = await fetchNui<ModerateResponse>(
        "moderateReportAction",
        { reportId, action },
        { ok: true, message: "Done." },
      ).catch(
        (): ModerateResponse => ({
          ok: false,
          message: "Failed action.",
        }),
      );
      setMessage(response.message || (response.ok ? "Action done." : "Action failed."));
      if (response.ok) {
        void loadReports();
      }
    },
    [loadReports],
  );

  return (
    <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div className="mb-4 space-y-3">
        <div className="space-y-0.5">
          <h2 className="text-xl font-semibold leading-tight text-[var(--ds-text-primary)]">Reports</h2>
          <p className="text-sm text-[var(--ds-text-secondary)]">Review and moderate listing abuse reports.</p>
        </div>
        <div className="flex flex-wrap items-end gap-2 rounded-lg bg-[var(--ds-bg-elevated)]/35 px-3 py-2">
          <div className="grid gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Status</Label>
            <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v as "all" | ReportStatus)}>
              <SelectTrigger className="h-9 w-[150px]"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="reviewed">Reviewed</SelectItem>
                <SelectItem value="resolved">Resolved</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Reason</Label>
            <Select value={reasonFilter} onValueChange={(v) => setReasonFilter(v as "all" | ReportReason)}>
              <SelectTrigger className="h-9 w-[150px]"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="Scam">Scam</SelectItem>
                <SelectItem value="Wrong Price">Wrong Price</SelectItem>
                <SelectItem value="Abuse">Abuse</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-1">
            <Label className="text-[10px] uppercase text-[var(--ds-text-muted)]">Search</Label>
            <Input
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Search reports..."
              className="h-9 w-[220px]"
            />
          </div>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-auto rounded-xl bg-[var(--ds-bg-card)]/70 p-3">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Listing</TableHead>
              <TableHead>Reason</TableHead>
              <TableHead>Reporter</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((report) => (
              <TableRow key={report.id}>
                <TableCell>
                  <div className="text-sm font-medium text-[var(--ds-text-primary)]">{report.listingTitle}</div>
                  <div className="text-xs text-[var(--ds-text-secondary)]">
                    Seller: {report.sellerName || report.sellerId} · ${Number(report.listingPrice || 0).toFixed(2)}
                  </div>
                  {report.description ? (
                    <div className="mt-1 text-xs text-[var(--ds-text-muted)]">{report.description}</div>
                  ) : null}
                </TableCell>
                <TableCell className="text-sm">{report.reason}</TableCell>
                <TableCell className="text-sm">{report.reporterName || report.reporterId}</TableCell>
                <TableCell className="text-sm">{report.status}</TableCell>
                <TableCell className="text-right">
                  <div className="flex justify-end gap-2">
                    <Button size="sm" variant="secondary" onClick={() => void runAction(report.id, "resolve")}>
                      Resolve
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() =>
                        setPendingModeration({ reportId: report.id, action: "remove_listing" })
                      }
                    >
                      Remove Listing
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() =>
                        setPendingModeration({ reportId: report.id, action: "ban_seller" })
                      }
                    >
                      Ban Seller
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
            {filtered.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="py-8 text-center text-sm text-[var(--ds-text-muted)]">
                  {isLoading ? "Loading reports..." : "No reports found."}
                </TableCell>
              </TableRow>
            ) : null}
          </TableBody>
        </Table>
      </div>

      <div className="mt-3 flex items-center justify-between text-xs text-[var(--ds-text-muted)]">
        <div>{message || `Showing ${filtered.length} / ${total} reports`}</div>
        <div className="flex items-center gap-2">
          <Button size="sm" variant="ghost" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
            Prev
          </Button>
          <span>Page {page} / {totalPages}</span>
          <Button size="sm" variant="ghost" disabled={page >= totalPages} onClick={() => setPage((p) => Math.min(totalPages, p + 1))}>
            Next
          </Button>
        </div>
      </div>

      <ConfirmDialog
        open={pendingModeration !== null}
        title={
          pendingModeration ? MODERATION_CONFIRM[pendingModeration.action].title : undefined
        }
        description={
          pendingModeration ? MODERATION_CONFIRM[pendingModeration.action].description : ""
        }
        confirmLabel={
          pendingModeration ? MODERATION_CONFIRM[pendingModeration.action].confirmLabel : undefined
        }
        destructive
        onCancel={() => setPendingModeration(null)}
        onConfirm={() => {
          if (!pendingModeration) return;
          const { reportId, action } = pendingModeration;
          setPendingModeration(null);
          void runAction(reportId, action);
        }}
      />
    </section>
  );
}
