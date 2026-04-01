"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, Loader2, MapPin, Package } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { AppHeader } from "@/components/app-header";
import { createClient } from "@/utils/supabase/client";
import { CONFIG } from "@/lib/config";
import type { AppUser } from "@/lib/types";

type ReportRecord = {
  id: string;
  title: string;
  type: "lost" | "found";
  location: string;
  image_urls?: string[];
  created_at?: string;
};

type ReportQueryRow = {
  id: string;
  title: string | null;
  created_at: string | null;
  location_lost?: string | null;
  location_found?: string | null;
  image_urls?: string[] | null;
};

const TYPE_BADGE: Record<ReportRecord["type"], string> = {
  lost: "text-white bg-[#e31e24] border-transparent",
  found: "text-[#203e7e] bg-blue-50 border-blue-100",
};

export default function ProfileReportsPage() {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [recordsLoading, setRecordsLoading] = useState(true);
  const [records, setRecords] = useState<ReportRecord[]>([]);
  const [isSigningOut, setIsSigningOut] = useState(false);

  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const loadReportRecords = useCallback(async (userId: string) => {
    setRecordsLoading(true);

    const [lostRes, foundRes] = await Promise.all([
      supabase.from("lost_items").select("id,title,created_at,location_lost,image_urls").eq("user_id", userId).order("created_at", { ascending: false }),
      supabase.from("found_items").select("id,title,created_at,location_found,image_urls").eq("user_id", userId).order("created_at", { ascending: false }),
    ]);

    const merged: ReportRecord[] = [];

    if (!lostRes.error && lostRes.data) {
      merged.push(
        ...lostRes.data.map((item: ReportQueryRow) => ({
          id: item.id,
          title: item.title || "Untitled lost item",
          type: "lost" as const,
          location: item.location_lost || "Unknown location",
          image_urls: item.image_urls || undefined,
          created_at: item.created_at || undefined,
        }))
      );
    }

    if (!foundRes.error && foundRes.data) {
      merged.push(
        ...foundRes.data.map((item: ReportQueryRow) => ({
          id: item.id,
          title: item.title || "Untitled found item",
          type: "found" as const,
          location: item.location_found || "Unknown location",
          image_urls: item.image_urls || undefined,
          created_at: item.created_at || undefined,
        }))
      );
    }

    merged.sort((a, b) => {
      const aTime = a.created_at ? new Date(a.created_at).getTime() : 0;
      const bTime = b.created_at ? new Date(b.created_at).getTime() : 0;
      return bTime - aTime;
    });

    setRecords(merged);
    setRecordsLoading(false);
  }, [supabase]);

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
        await loadReportRecords(authUser.id);
      } catch {
        toast.error("Unable to load your reports.");
      } finally {
        setLoading(false);
      }
    };

    init();
  }, [loadReportRecords, router, supabase]);

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
    <div className="min-h-screen bg-gray-50 pb-28 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-8">
        <div className="mb-4 flex items-center">
          <button
            type="button"
            onClick={() => router.push("/profile")}
            className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-gray-200 bg-white text-gray-600"
            aria-label="Back to profile"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
        </div>

        {recordsLoading ? (
          <div className="rounded-2xl bg-white border border-gray-100 p-6 text-center shadow-sm">
            <Loader2 className="w-6 h-6 animate-spin text-[#203e7e] mx-auto" />
            <p className="text-sm text-gray-500 mt-3">Loading your report records...</p>
          </div>
        ) : records.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-gray-200 bg-white p-6 text-center">
            <p className="text-sm text-gray-500">No report records found yet.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {records.map((record) => (
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
