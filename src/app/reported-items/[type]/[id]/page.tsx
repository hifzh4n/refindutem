"use client";

import { useEffect, useMemo, useState } from "react";
import { CalendarDays, ChevronLeft, Loader2, MapPin, Package, Tag, Text, X } from "lucide-react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import { AppHeader } from "@/components/app-header";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";

type ReportType = "lost" | "found";

type ReportDetail = {
  id: string;
  ownerId: string;
  title: string;
  description: string;
  category: string;
  location: string;
  status: string;
  type: ReportType;
  dateReported: string;
  dateEvent: string;
  imageUrls: string[];
};

type LostRow = {
  id: string;
  user_id: string;
  title: string | null;
  description: string | null;
  category: string | null;
  location_lost: string | null;
  status: string | null;
  created_at: string | null;
  date_lost: string | null;
  image_urls: string[] | null;
};

type FoundRow = {
  id: string;
  user_id: string;
  title: string | null;
  description: string | null;
  category: string | null;
  location_found: string | null;
  status: string | null;
  created_at: string | null;
  date_found: string | null;
  image_urls: string[] | null;
};

const TYPE_BADGE: Record<ReportType, string> = {
  lost: "text-white bg-[#e31e24] border-transparent",
  found: "text-[#203e7e] bg-blue-50 border-blue-100",
};

function formatDate(value?: string): string {
  if (!value) return "Not available";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "Not available";
  return parsed.toLocaleString();
}

export default function ReportDetailsPage() {
  const params = useParams<{ type?: string; id?: string }>();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const [loading, setLoading] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [isUpdatingStatus, setIsUpdatingStatus] = useState(false);
  const [isImagePreviewOpen, setIsImagePreviewOpen] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [record, setRecord] = useState<ReportDetail | null>(null);

  const reportType = params?.type === "lost" || params?.type === "found" ? params.type : null;
  const reportId = typeof params?.id === "string" ? params.id : null;

  useEffect(() => {
    const loadRecord = async () => {
      if (!reportType || !reportId) {
        router.push(CONFIG.ROUTES.REPORTED_ITEMS);
        return;
      }

      try {
        const { data: authData, error: authError } = await supabase.auth.getUser();
        if (authError || !authData.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }
        setCurrentUserId(authData.user.id);

        if (reportType === "lost") {
          const { data, error } = await supabase
            .from("lost_items")
            .select("id,user_id,title,description,category,location_lost,status,created_at,date_lost,image_urls")
            .eq("id", reportId)
            .single();

          if (error || !data) {
            toast.error("Report not found.");
            router.push(CONFIG.ROUTES.REPORTED_ITEMS);
            return;
          }

          const item = data as LostRow;
          setRecord({
            id: item.id,
            ownerId: item.user_id,
            title: item.title || "Untitled lost item",
            description: item.description || "No description provided.",
            category: item.category || "Uncategorized",
            location: item.location_lost || "Unknown location",
            status: item.status || "open",
            type: "lost",
            dateReported: item.created_at || "",
            dateEvent: item.date_lost || "",
            imageUrls: item.image_urls || [],
          });
          return;
        }

        const { data, error } = await supabase
          .from("found_items")
          .select("id,user_id,title,description,category,location_found,status,created_at,date_found,image_urls")
          .eq("id", reportId)
          .single();

        if (error || !data) {
          toast.error("Report not found.");
          router.push(CONFIG.ROUTES.REPORTED_ITEMS);
          return;
        }

        const item = data as FoundRow;
        setRecord({
          id: item.id,
          ownerId: item.user_id,
          title: item.title || "Untitled found item",
          description: item.description || "No description provided.",
          category: item.category || "Uncategorized",
          location: item.location_found || "Unknown location",
          status: item.status || "open",
          type: "found",
          dateReported: item.created_at || "",
          dateEvent: item.date_found || "",
          imageUrls: item.image_urls || [],
        });
      } catch {
        toast.error("Unable to load report details.");
        router.push(CONFIG.ROUTES.REPORTED_ITEMS);
      } finally {
        setLoading(false);
      }
    };

    loadRecord();
  }, [reportType, reportId, router, supabase]);

  const handleMarkAsSolved = async () => {
    if (!record || !currentUserId || record.ownerId !== currentUserId) return;
    if (record.status.toLowerCase() === "resolved" || record.status.toLowerCase() === "closed") return;

    try {
      setIsUpdatingStatus(true);
      const table = record.type === "lost" ? "lost_items" : "found_items";
      const { error } = await supabase
        .from(table)
        .update({ status: "resolved", updated_at: new Date().toISOString() })
        .eq("id", record.id);

      if (error) {
        toast.error(error.message || "Unable to update report status.");
        return;
      }

      if (typeof window !== "undefined") {
        window.localStorage.setItem("has_unread_notifications", "true");
        window.dispatchEvent(new Event("notifications:new"));
        window.dispatchEvent(new CustomEvent("notifications:new"));
      }

      const { error: notificationError } = await supabase.from("notifications").insert({
        user_id: currentUserId,
        type: `${record.type}-resolved`,
        message: `You marked your ${record.type} report \"${record.title}\" as solved.`,
        related_item_id: record.id,
        related_item_type: record.type,
      });

      if (notificationError) {
        console.warn("Failed to create solved notification:", notificationError);
        toast.success("Report marked as solved.");
      } else {
        toast.success("Report marked as solved.");
      }

      setRecord((prev) => (prev ? { ...prev, status: "resolved" } : prev));
    } finally {
      setIsUpdatingStatus(false);
    }
  };

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

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Loader2 className="w-7 h-7 animate-spin text-[#203e7e]" />
      </div>
    );
  }

  if (!record) {
    return null;
  }

  const isOwner = !!currentUserId && record.ownerId === currentUserId;
  const isSolved = record.status.toLowerCase() === "resolved" || record.status.toLowerCase() === "closed";

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-4 space-y-3">
        <button
          type="button"
          onClick={() => router.push(CONFIG.ROUTES.REPORTED_ITEMS)}
          className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#203e7e]/20 bg-white text-[#203e7e] shadow-sm transition hover:bg-[#203e7e]/5"
          aria-label="Back to reported items"
        >
          <ChevronLeft className="w-5 h-5" strokeWidth={2.5} />
        </button>

        <article className="rounded-2xl border border-gray-100 bg-white shadow-sm overflow-hidden">
          <div className="h-52 bg-gray-100 border-b border-gray-100 flex items-center justify-center overflow-hidden">
            {record.imageUrls.length > 0 ? (
              <button
                type="button"
                onClick={() => setIsImagePreviewOpen(true)}
                className="w-full h-full"
                aria-label="View full image"
              >
                <img src={record.imageUrls[0]} alt={record.title} className="w-full h-full object-cover cursor-zoom-in" />
              </button>
            ) : (
              <Package className="w-12 h-12 text-gray-300" />
            )}
          </div>

          <div className="p-4 space-y-3">
            <div className="flex items-start justify-between gap-3">
              <div>
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded border uppercase tracking-wider ${TYPE_BADGE[record.type]}`}>
                  {record.type === "lost" ? "Lost" : "Found"}
                </span>
                <h1 className="mt-2 text-lg font-bold text-gray-900 leading-tight">{record.title}</h1>
              </div>
              <span className="text-[10px] font-semibold uppercase rounded-full px-2 py-1 bg-gray-100 text-gray-600">
                {record.status}
              </span>
            </div>

            <div className="grid grid-cols-1 gap-2 text-sm text-gray-700">
              <div className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 flex items-start gap-2">
                <MapPin className="w-4 h-4 mt-0.5 text-gray-400" />
                <div>
                  <p className="text-[11px] uppercase tracking-wide text-gray-500 font-semibold">Location</p>
                  <p className="font-medium text-gray-800">{record.location}</p>
                </div>
              </div>

              <div className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 flex items-start gap-2">
                <Tag className="w-4 h-4 mt-0.5 text-gray-400" />
                <div>
                  <p className="text-[11px] uppercase tracking-wide text-gray-500 font-semibold">Category</p>
                  <p className="font-medium text-gray-800">{record.category}</p>
                </div>
              </div>

              <div className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 flex items-start gap-2">
                <CalendarDays className="w-4 h-4 mt-0.5 text-gray-400" />
                <div>
                  <p className="text-[11px] uppercase tracking-wide text-gray-500 font-semibold">
                    {record.type === "lost" ? "Date Lost / Reported At" : "Date Found / Reported At"}
                  </p>
                  <p className="font-medium text-gray-800">{formatDate(record.dateReported || record.dateEvent)}</p>
                </div>
              </div>

              <div className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 flex items-start gap-2">
                <Text className="w-4 h-4 mt-0.5 text-gray-400" />
                <div>
                  <p className="text-[11px] uppercase tracking-wide text-gray-500 font-semibold">Description</p>
                  <p className="font-medium text-gray-800 whitespace-pre-wrap">{record.description}</p>
                </div>
              </div>
            </div>

            {isOwner && (
              <button
                type="button"
                onClick={handleMarkAsSolved}
                disabled={isSolved || isUpdatingStatus}
                className="w-full h-10 rounded-lg bg-[#203e7e] text-white text-sm font-semibold transition hover:bg-[#193268] disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                {isUpdatingStatus ? "Updating..." : isSolved ? "Solved" : "Mark as Solved"}
              </button>
            )}
          </div>
        </article>
      </main>

      {isImagePreviewOpen && record.imageUrls[0] ? (
        <div
          className="fixed inset-0 z-[70] bg-black/85 flex items-center justify-center p-4"
          onClick={() => setIsImagePreviewOpen(false)}
        >
          <button
            type="button"
            className="absolute top-4 right-4 h-9 w-9 rounded-full bg-white/15 text-white flex items-center justify-center"
            onClick={() => setIsImagePreviewOpen(false)}
            aria-label="Close full image preview"
          >
            <X className="w-5 h-5" />
          </button>

          <img
            src={record.imageUrls[0]}
            alt={record.title}
            className="max-w-full max-h-[85vh] rounded-xl object-contain"
            onClick={(event) => event.stopPropagation()}
          />
        </div>
      ) : null}
    </div>
  );
}
