"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronRight, ClipboardList, Loader2, MapPin, Package, Search } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { createClient } from "@/utils/supabase/client";
import { CONFIG } from "@/lib/config";
import type { AppUser } from "@/lib/types";
import { AppHeader } from "@/components/app-header";
import { Input } from "@/components/ui/input";

type ReportType = "lost" | "found";

type ReportRecord = {
  id: string;
  title: string;
  status: string;
  type: ReportType;
  location: string;
  image_urls?: string[];
  createdAt?: string;
};

type QueryRow = {
  id: string;
  title: string | null;
  status: string | null;
  location_lost?: string | null;
  location_found?: string | null;
  image_urls?: string[] | null;
  created_at: string | null;
};

const TYPE_BADGE: Record<ReportType, string> = {
  lost: "text-white bg-[#e31e24] border-transparent",
  found: "text-[#203e7e] bg-blue-50 border-blue-100",
};

const STATUS_OPTIONS = ["all", "open", "claimed"] as const;
type StatusFilter = (typeof STATUS_OPTIONS)[number];

function isResolvedStatus(value?: string | null): boolean {
  if (!value) return false;
  const normalized = value.toLowerCase();
  return normalized === "resolved" || normalized === "closed";
}

export default function ReportedItemsPage() {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [recordsLoading, setRecordsLoading] = useState(true);
  const [records, setRecords] = useState<ReportRecord[]>([]);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [typeFilter, setTypeFilter] = useState<"all" | ReportType>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");

  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const loadRecords = useCallback(async (userId: string) => {
    setRecordsLoading(true);

    const [lostRes, foundRes] = await Promise.all([
      supabase.from("lost_items").select("id,title,status,location_lost,image_urls,created_at").eq("user_id", userId).order("created_at", { ascending: false }),
      supabase.from("found_items").select("id,title,status,location_found,image_urls,created_at").eq("user_id", userId).order("created_at", { ascending: false }),
    ]);

    const merged: ReportRecord[] = [];

    if (!lostRes.error && lostRes.data) {
      merged.push(
        ...lostRes.data
        .filter((item: QueryRow) => !isResolvedStatus(item.status))
        .map((item: QueryRow) => ({
          id: item.id,
          title: item.title || "Untitled lost item",
          status: item.status || "open",
          type: "lost" as const,
          location: item.location_lost || "Unknown location",
          image_urls: item.image_urls || undefined,
          createdAt: item.created_at || undefined,
        }))
      );
    }

    if (!foundRes.error && foundRes.data) {
      merged.push(
        ...foundRes.data
        .filter((item: QueryRow) => !isResolvedStatus(item.status))
        .map((item: QueryRow) => ({
          id: item.id,
          title: item.title || "Untitled found item",
          status: item.status || "open",
          type: "found" as const,
          location: item.location_found || "Unknown location",
          image_urls: item.image_urls || undefined,
          createdAt: item.created_at || undefined,
        }))
      );
    }

    merged.sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return bTime - aTime;
    });

    setRecords(merged);
    setRecordsLoading(false);
  }, [supabase]);

  const filteredRecords = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();

    return records.filter((record) => {
      const matchesQuery = query.length === 0 || record.title.toLowerCase().includes(query);
      const matchesType = typeFilter === "all" || record.type === typeFilter;
      const matchesStatus = statusFilter === "all" || record.status.toLowerCase() === statusFilter;
      return matchesQuery && matchesType && matchesStatus;
    });
  }, [records, searchQuery, typeFilter, statusFilter]);

  useEffect(() => {
    const init = async () => {
      try {
        const { data, error } = await supabase.auth.getUser();
        if (error || !data.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }

        const authUser = data.user as AppUser;
        setUser(authUser);
        await loadRecords(authUser.id);
      } finally {
        setLoading(false);
      }
    };

    init();
  }, [loadRecords, router, supabase]);

  const handleLogout = async () => {
    try {
      setIsSigningOut(true);
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      router.push(CONFIG.ROUTES.LOGIN);
    } catch {
      toast.error("An error occurred during logout.");
    } finally {
      setIsSigningOut(false);
    }
  };

  if (loading || !user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Loader2 className="w-7 h-7 animate-spin text-[#203e7e]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-4">
        <section className="rounded-2xl bg-white border border-gray-100 p-3 shadow-sm mb-3 space-y-3">
          <div className="relative">
            <Search className="w-4 h-4 text-gray-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
            <Input
              type="search"
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              placeholder="Search by item title"
              className="h-10 pl-8"
              aria-label="Search reported items"
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <label className="text-xs text-gray-500 font-semibold uppercase tracking-wide">
              Type
              <select
                value={typeFilter}
                onChange={(event) => setTypeFilter(event.target.value as "all" | ReportType)}
                className="mt-1 h-10 w-full rounded-lg border border-gray-200 bg-white px-2.5 text-sm text-gray-800 outline-none focus-visible:border-[#203e7e] focus-visible:ring-2 focus-visible:ring-[#203e7e]/20"
                aria-label="Filter by report type"
              >
                <option value="all">All</option>
                <option value="lost">Lost</option>
                <option value="found">Found</option>
              </select>
            </label>

            <label className="text-xs text-gray-500 font-semibold uppercase tracking-wide">
              Status
              <select
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value as StatusFilter)}
                className="mt-1 h-10 w-full rounded-lg border border-gray-200 bg-white px-2.5 text-sm text-gray-800 outline-none focus-visible:border-[#203e7e] focus-visible:ring-2 focus-visible:ring-[#203e7e]/20"
                aria-label="Filter by status"
              >
                {STATUS_OPTIONS.map((status) => (
                  <option key={status} value={status}>
                    {status === "all" ? "All" : status.charAt(0).toUpperCase() + status.slice(1)}
                  </option>
                ))}
              </select>
            </label>
          </div>
        </section>

        {recordsLoading ? (
          <div className="rounded-2xl bg-white border border-gray-100 p-6 text-center shadow-sm">
            <Loader2 className="w-6 h-6 animate-spin text-[#203e7e] mx-auto" />
            <p className="text-sm text-gray-500 mt-3">Loading your reported items...</p>
          </div>
        ) : filteredRecords.length === 0 ? (
          <div className="rounded-2xl bg-white border border-gray-100 p-8 text-center shadow-sm">
            <ClipboardList className="w-8 h-8 text-gray-300 mx-auto" />
            <h2 className="font-semibold text-gray-800 mt-3">No matching items found</h2>
            <p className="text-sm text-gray-500 mt-1">Try changing your search keywords or filters.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredRecords.map((record) => (
              <button
                key={`${record.type}-${record.id}`}
                type="button"
                onClick={() => router.push(`/reported-items/${record.type}/${record.id}`)}
                className="w-full text-left bg-white border border-gray-100 rounded-xl px-3.5 py-3 grid grid-cols-[64px_1fr_20px] items-center gap-3 shadow-sm active:scale-[0.99] transition-transform hover:shadow-md"
              >
                <div className="w-16 h-16 rounded-lg bg-gray-50 border border-gray-100 flex items-center justify-center overflow-hidden">
                  {record.image_urls && record.image_urls.length > 0 ? (
                    <img src={record.image_urls[0]} alt={record.title} className="w-full h-full object-cover" />
                  ) : (
                    <Package className="w-7 h-7 text-gray-300" />
                  )}
                </div>
                <div className="min-w-0">
                  <div className="flex items-start gap-2">
                    <span className={`text-[9px] font-bold px-2 py-0.5 rounded border uppercase tracking-wider ${TYPE_BADGE[record.type]}`}>
                      {record.type === "lost" ? "Lost" : "Found"}
                    </span>
                  </div>
                  <h3 className="mt-1 text-sm font-bold text-gray-900 truncate leading-tight">{record.title}</h3>
                  <p className="text-[11px] text-gray-500 mt-1 flex items-center gap-1">
                    <MapPin className="w-3 h-3 text-gray-400" />
                    {record.location}
                  </p>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-300 justify-self-end" />
              </button>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
