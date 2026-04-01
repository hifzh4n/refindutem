"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronLeft, Shield, KeyRound, Loader2, X, Eye, EyeOff, Key, ChevronRight, MapPin, Package } from "lucide-react";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { createClient } from "@/utils/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { CONFIG, getUserRole } from "@/lib/config";
import type { AppUser } from "@/lib/types";

type ReportRecord = {
  id: string;
  title: string;
  type: "lost" | "found";
  status: string;
  location: string;
  image_urls?: string[];
  created_at?: string;
};

type ReportQueryRow = {
  id: string;
  title: string | null;
  status: string | null;
  created_at: string | null;
  location_lost?: string | null;
  location_found?: string | null;
  image_urls?: string[] | null;
};

const TYPE_BADGE: Record<ReportRecord["type"], string> = {
  lost: "text-white bg-[#e31e24] border-transparent",
  found: "text-[#203e7e] bg-blue-50 border-blue-100",
};

function isResolvedStatus(value?: string | null): boolean {
  if (!value) return false;
  const normalized = value.toLowerCase();
  return normalized === "resolved" || normalized === "closed";
}

function getRecordRoute(type: ReportRecord["type"], id: string): string | null {
  return `/reported-items/${type}/${id}`;
}

export default function ProfilePage() {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [records, setRecords] = useState<ReportRecord[]>([]);
  const [recordsLoading, setRecordsLoading] = useState(true);

  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showOldPassword, setShowOldPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [updatingPassword, setUpdatingPassword] = useState(false);
  const [showSecurityModal, setShowSecurityModal] = useState(false);

  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const previewRecords = records.slice(0, 3);

  const loadReportRecords = useCallback(async (userId: string) => {
    setRecordsLoading(true);

    const [lostRes, foundRes] = await Promise.all([
      supabase.from("lost_items").select("id,title,status,created_at,location_lost,image_urls").eq("user_id", userId).order("created_at", { ascending: false }),
      supabase.from("found_items").select("id,title,status,created_at,location_found,image_urls").eq("user_id", userId).order("created_at", { ascending: false }),
    ]);

    const merged: ReportRecord[] = [];

    if (!lostRes.error && lostRes.data) {
      merged.push(
        ...lostRes.data
        .map((item: ReportQueryRow) => ({
          id: item.id,
          title: item.title || "Untitled lost item",
          type: "lost" as const,
          status: item.status || "open",
          location: item.location_lost || "Unknown location",
          image_urls: item.image_urls || undefined,
          created_at: item.created_at || undefined,
        }))
      );
    }

    if (!foundRes.error && foundRes.data) {
      merged.push(
        ...foundRes.data
        .map((item: ReportQueryRow) => ({
          id: item.id,
          title: item.title || "Untitled found item",
          type: "found" as const,
          status: item.status || "open",
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
        toast.error("Unable to load your profile.");
        router.push(CONFIG.ROUTES.LOGIN);
      } finally {
        setLoading(false);
      }
    };

    init();
  }, [loadReportRecords, router, supabase]);

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    const currentUser = user;

    if (!oldPassword || !newPassword || !confirmPassword) {
      toast.error("Please fill in all password fields.");
      return;
    }

    if (!currentUser?.email) {
      toast.error("Your account email is missing. Please sign in again.");
      return;
    }

    if (newPassword.length < CONFIG.AUTH.PASSWORD_MIN_LENGTH) {
      toast.error(`Password must be at least ${CONFIG.AUTH.PASSWORD_MIN_LENGTH} characters.`);
      return;
    }

    if (newPassword !== confirmPassword) {
      toast.error("Passwords do not match.");
      return;
    }

    try {
      setUpdatingPassword(true);
      const { error: verifyError } = await supabase.auth.signInWithPassword({
        email: currentUser.email,
        password: oldPassword,
      });

      if (verifyError) {
        toast.error("Current password is incorrect.");
        return;
      }

      const { error } = await supabase.auth.updateUser({ password: newPassword });
      if (error) {
        toast.error(error.message || "Failed to update password.");
        return;
      }

      toast.success("Password updated successfully.");
      setOldPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setShowOldPassword(false);
      setShowNewPassword(false);
      setShowConfirmPassword(false);
      setShowSecurityModal(false);
    } catch {
      toast.error("Unexpected error while updating password.");
    } finally {
      setUpdatingPassword(false);
    }
  };

  if (loading || !user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Loader2 className="w-7 h-7 animate-spin text-[#203e7e]" />
      </div>
    );
  }

  const profileName = user.user_metadata?.full_name || "Unknown User";
  const campusId = user.email?.split("@")[0] || "-";
  const roleCode = user.user_metadata?.user_role || getUserRole(user.email);
  const roleLabel = roleCode === "student" ? "Campus Explorer" : "Campus Guardian";
  const initials = profileName
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || "U";
  const avatarUrl = user.user_metadata?.avatar_url;

  const lostCount = records.filter((record) => record.type === "lost").length;
  const foundCount = records.filter((record) => record.type === "found").length;
  const totalRecords = records.length;

  return (
    <div className="min-h-screen bg-[#eef1f7] flex justify-center px-3 py-4 pb-24">
      <div className="w-full md:max-w-md lg:max-w-lg space-y-4">
        <div className="relative overflow-hidden rounded-3xl border border-white/80 bg-white shadow-[0_16px_36px_rgba(23,43,77,0.16)]">
          <div className="relative h-32 bg-[linear-gradient(130deg,#203e7e_0%,#2d5dc5_55%,#6ea0ff_100%)]">
            <div className="absolute inset-0 opacity-30" style={{ backgroundImage: "radial-gradient(circle at 22% 20%, #ffffff 2px, transparent 2px)", backgroundSize: "24px 24px" }} />
            <button
              onClick={() => router.push(CONFIG.ROUTES.DASHBOARD)}
              className="absolute left-3 top-3 inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/55 bg-white/30 text-white backdrop-blur-md transition hover:bg-white/45"
              aria-label="Back to dashboard"
            >
              <ChevronLeft className="h-5 w-5" strokeWidth={2.5} />
            </button>
          </div>

          <div className="relative px-4 pb-4 pt-14">
            <div className="absolute -top-11 left-4 h-22 w-22 rounded-full border-4 border-white bg-white shadow-lg overflow-hidden">
              {avatarUrl ? (
                <div
                  className="h-full w-full bg-cover bg-center"
                  style={{ backgroundImage: `url(${avatarUrl})` }}
                  aria-label="Profile picture"
                />
              ) : (
                <div className="h-full w-full bg-gradient-to-br from-[#203e7e] to-[#3972ff] text-white flex items-center justify-center text-xl font-bold tracking-wide">
                  {initials}
                </div>
              )}
            </div>

            <div className="space-y-1">
              <h1 className="text-xl font-bold text-gray-900 leading-tight">{profileName}</h1>
              <p className="text-sm text-gray-500">@{campusId.toLowerCase()}</p>
              <div className="inline-flex items-center gap-2 rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-[#203e7e] border border-blue-100">
                <Shield className="h-3.5 w-3.5" />
                {roleLabel}
              </div>
            </div>

            <div className="mt-4 grid grid-cols-3 gap-2">
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{totalRecords}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Reports</p>
              </div>
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{lostCount}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Lost</p>
              </div>
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{foundCount}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Found</p>
              </div>
            </div>
          </div>
        </div>

        <motion.section
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.05 }}
          className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4"
        >
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="text-sm font-semibold text-gray-900">My Report Records</h2>
            {records.length > 3 ? (
              <button
                type="button"
                onClick={() => router.push("/profile/reports")}
                className="text-xs font-semibold text-[#203e7e] hover:underline"
              >
                View all
              </button>
            ) : null}
          </div>

          {recordsLoading ? (
            <div className="py-8 flex justify-center">
              <Loader2 className="w-5 h-5 animate-spin text-[#203e7e]" />
            </div>
          ) : records.length === 0 ? (
            <div className="rounded-xl border border-dashed border-gray-200 bg-gray-50 p-4 text-center">
              <p className="text-sm text-gray-500">No report records found yet.</p>
            </div>
          ) : (
            <div className="space-y-2.5">
              {previewRecords.map((record) => {
                const route = getRecordRoute(record.type, record.id);

                return (
                  <button
                    key={`${record.type}-${record.id}`}
                    type="button"
                    onClick={() => route && router.push(route)}
                    disabled={!route}
                    className="w-full text-left bg-white border border-gray-100 rounded-xl px-3.5 py-3 grid grid-cols-[64px_1fr_20px] items-center gap-3 shadow-sm transition-transform enabled:hover:shadow-md enabled:active:scale-[0.99] disabled:cursor-default"
                    aria-label={route ? `Open ${record.type} report details` : "Report details unavailable"}
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
                          {record.type === "lost" ? "Lost" : record.type === "found" ? "Found" : "Other"}
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
                );
              })}
            </div>
          )}
        </motion.section>

        <motion.button
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          onClick={() => setShowSecurityModal(true)}
          className="w-full inline-flex items-center justify-center gap-2 rounded-2xl border border-[#203e7e]/20 bg-white px-4 py-3 text-sm font-semibold text-[#203e7e] shadow-sm hover:bg-[#203e7e]/5"
        >
          <KeyRound className="w-4 h-4" />
          Change Password
        </motion.button>

        <AnimatePresence>
          {showSecurityModal && (
            <>
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                onClick={() => !updatingPassword && setShowSecurityModal(false)}
                className="fixed inset-0 z-40 bg-black/35 backdrop-blur-[2px]"
              />

              <motion.div
                initial={{ opacity: 0, y: 160 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 160 }}
                transition={{ type: "spring", stiffness: 340, damping: 30 }}
                className="fixed inset-0 z-50 flex items-center justify-center p-4"
              >
                <div className="w-full max-w-md rounded-3xl border border-white/80 bg-white p-4 shadow-[0_18px_36px_rgba(19,38,75,0.28)]">
                  <div className="flex items-center justify-between mb-3">
                    <h2 className="text-sm font-bold text-gray-900">Security</h2>
                    <button
                      onClick={() => setShowSecurityModal(false)}
                      className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-50"
                      aria-label="Close password form"
                      disabled={updatingPassword}
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>

                  <p className="text-xs text-gray-500 mb-3">Only password can be changed.</p>

                  <form className="space-y-3" onSubmit={handleChangePassword}>
                    <div className="space-y-1.5">
                      <Label htmlFor="oldPassword" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Old Password</Label>
                      <div className="relative group">
                        <Key className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                        <Input
                          id="oldPassword"
                          type={showOldPassword ? "text" : "password"}
                          value={oldPassword}
                          onChange={(e) => setOldPassword(e.target.value)}
                          className="pl-12 pr-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm"
                          placeholder="Enter current password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowOldPassword((prev) => !prev)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                          aria-label={showOldPassword ? "Hide old password" : "Show old password"}
                        >
                          {showOldPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                        </button>
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <Label htmlFor="newPassword" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">New Password</Label>
                      <div className="relative group">
                        <Key className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                        <Input
                          id="newPassword"
                          type={showNewPassword ? "text" : "password"}
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          className="pl-12 pr-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm"
                          placeholder="Enter new password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowNewPassword((prev) => !prev)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                          aria-label={showNewPassword ? "Hide new password" : "Show new password"}
                        >
                          {showNewPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                        </button>
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <Label htmlFor="confirmPassword" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Confirm Password</Label>
                      <div className="relative group">
                        <Key className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                        <Input
                          id="confirmPassword"
                          type={showConfirmPassword ? "text" : "password"}
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                          className="pl-12 pr-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm"
                          placeholder="Confirm new password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowConfirmPassword((prev) => !prev)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                          aria-label={showConfirmPassword ? "Hide confirm password" : "Show confirm password"}
                        >
                          {showConfirmPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                        </button>
                      </div>
                    </div>

                    <Button type="submit" disabled={updatingPassword} className="w-full bg-[#203e7e] hover:bg-[#1a3268]">
                      {updatingPassword ? "Updating..." : "Change Password"}
                    </Button>
                  </form>
                </div>
              </motion.div>
            </>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
