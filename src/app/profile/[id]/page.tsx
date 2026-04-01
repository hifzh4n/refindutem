"use client";

import { useEffect, useMemo, useState } from "react";
import { ChevronLeft, Loader2, MapPin, Package, Shield } from "lucide-react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import { AppHeader } from "@/components/app-header";
import { CONFIG } from "@/lib/config";
import type { AppUser } from "@/lib/types";
import { createClient } from "@/utils/supabase/client";

type ProfileRow = {
  id: string;
  full_name: string | null;
  matric_number: string | null;
  avatar_url: string | null;
};

type PublicProfile = {
  id: string;
  fullName: string;
  matricNumber: string;
  avatarUrl: string | null;
  lostCount: number;
  foundCount: number;
};

function getInitials(value?: string): string {
  const source = value?.trim() || "UTeM User";
  const parts = source.split(" ").filter(Boolean).slice(0, 2);
  const initials = parts.map((part) => part[0]?.toUpperCase() ?? "").join("");
  return initials || "U";
}

export default function PublicProfilePage() {
  const params = useParams<{ id?: string }>();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const profileId = typeof params?.id === "string" ? params.id : null;

  const [loading, setLoading] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [profile, setProfile] = useState<PublicProfile | null>(null);

  useEffect(() => {
    const loadProfile = async () => {
      if (!profileId) {
        router.push(CONFIG.ROUTES.PROFILE);
        return;
      }

      try {
        const { data: authData, error: authError } = await supabase.auth.getUser();
        if (authError || !authData.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }

        const authUser = authData.user as AppUser;
        setCurrentUserId(authUser.id);

        const [profileRes, lostCountRes, foundCountRes] = await Promise.all([
          supabase.from("profiles").select("id,full_name,matric_number,avatar_url").eq("id", profileId).maybeSingle(),
          supabase.from("lost_items").select("id", { count: "exact", head: true }).eq("user_id", profileId),
          supabase.from("found_items").select("id", { count: "exact", head: true }).eq("user_id", profileId),
        ]);

        const profileData = profileRes.data as ProfileRow | null;
        const fallbackName = profileId === authUser.id ? authUser.user_metadata?.full_name || "UTeM User" : "UTeM User";
        const fallbackMatric = profileId === authUser.id ? authUser.email?.split("@")[0]?.toUpperCase() || "-" : "-";
        const fallbackAvatar = profileId === authUser.id ? authUser.user_metadata?.avatar_url || null : null;

        setProfile({
          id: profileId,
          fullName: profileData?.full_name || fallbackName,
          matricNumber: profileData?.matric_number || fallbackMatric,
          avatarUrl: profileData?.avatar_url || fallbackAvatar,
          lostCount: lostCountRes.count || 0,
          foundCount: foundCountRes.count || 0,
        });
      } catch {
        toast.error("Unable to load profile.");
        router.push(CONFIG.ROUTES.REPORTED_ITEMS);
      } finally {
        setLoading(false);
      }
    };

    loadProfile();
  }, [profileId, router, supabase]);

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

  if (!profile) {
    return null;
  }

  const totalReports = profile.lostCount + profile.foundCount;

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-4 space-y-3">
        <button
          type="button"
          onClick={() => router.back()}
          className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#203e7e]/20 bg-white text-[#203e7e] shadow-sm transition hover:bg-[#203e7e]/5"
          aria-label="Back"
        >
          <ChevronLeft className="w-5 h-5" strokeWidth={2.5} />
        </button>

        <section className="rounded-2xl border border-gray-100 bg-white shadow-sm overflow-hidden">
          <div className="h-24 bg-[linear-gradient(130deg,#203e7e_0%,#2d5dc5_55%,#6ea0ff_100%)]" />

          <div className="px-4 pb-4 pt-12 relative">
            <div className="absolute -top-9 left-4 h-18 w-18 rounded-full border-4 border-white bg-white shadow-md overflow-hidden flex items-center justify-center">
              {profile.avatarUrl ? (
                <img src={profile.avatarUrl} alt={profile.fullName} className="h-full w-full object-cover" />
              ) : (
                <span className="text-lg font-bold text-[#203e7e]">{getInitials(profile.fullName)}</span>
              )}
            </div>

            <div className="space-y-1">
              <h1 className="text-xl font-bold text-gray-900">{profile.fullName}</h1>
              <p className="text-sm text-gray-600">Matric No: {profile.matricNumber}</p>
              <div className="inline-flex items-center gap-2 rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-[#203e7e] border border-blue-100">
                <Shield className="h-3.5 w-3.5" />
                Campus Member
              </div>
            </div>

            <div className="mt-4 grid grid-cols-3 gap-2">
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{totalReports}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Reports</p>
              </div>
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{profile.lostCount}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Lost</p>
              </div>
              <div className="rounded-2xl bg-gray-50 border border-gray-100 px-2 py-2 text-center">
                <p className="text-base font-bold text-gray-900">{profile.foundCount}</p>
                <p className="text-[10px] uppercase tracking-wide text-gray-500 font-semibold">Found</p>
              </div>
            </div>
          </div>
        </section>

        {currentUserId === profile.id ? (
          <button
            type="button"
            onClick={() => router.push(CONFIG.ROUTES.PROFILE)}
            className="w-full h-10 rounded-lg border border-gray-200 bg-white text-gray-800 text-sm font-semibold transition hover:bg-gray-50"
          >
            Go to My Profile
          </button>
        ) : null}
      </main>
    </div>
  );
}
