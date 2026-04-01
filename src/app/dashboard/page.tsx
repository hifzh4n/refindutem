"use client";

import { useEffect, useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { 
  Package, MapPin, ChevronRight
} from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/utils/supabase/client";
import { useRouter } from "next/navigation";
import { CONFIG } from "@/lib/config";
import type { AppUser } from "@/lib/types";
import { AppHeader } from "@/components/app-header";

interface RecentItem {
  id: string;
  title: string;
  location: string;
  type: "lost" | "found";
  image_urls?: string[];
  created_at: string;
  status?: string;
}

function isResolvedStatus(value?: string | null): boolean {
  if (!value) return false;
  const normalized = value.toLowerCase();
  return normalized === "resolved" || normalized === "closed";
}

export default function DashboardPage() {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [recentItems, setRecentItems] = useState<RecentItem[]>([]);
  const [itemsLoading, setItemsLoading] = useState(false);
  const [showLogoutModal, setShowLogoutModal] = useState(false);
  const [isSigningOut, setIsSigningOut] = useState(false);
  
  const supabase = useMemo(() => createClient(), []);
  const router = useRouter();

  useEffect(() => {
    const checkUser = async () => {
      try {
        const { data, error } = await supabase.auth.getUser();
        if (error || !data.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }
        setUser(data.user as AppUser);
      } catch (err) {
        console.error("Error fetching user:", err);
        router.push(CONFIG.ROUTES.LOGIN);
      } finally {
        setLoading(false);
      }
    };

    checkUser();
  }, [supabase, router]);

  useEffect(() => {
    const loadRecentItems = async () => {
      setItemsLoading(true);
      try {
        const [lostRes, foundRes] = await Promise.all([
          supabase
            .from("lost_items")
            .select("id,title,location_lost,image_urls,created_at,status")
            .order("created_at", { ascending: false })
            .limit(5),
          supabase
            .from("found_items")
            .select("id,title,location_found,image_urls,created_at,status")
            .order("created_at", { ascending: false })
            .limit(5),
        ]);

        const items: RecentItem[] = [];

        if (!lostRes.error && lostRes.data) {
          items.push(
            ...lostRes.data
            .filter((item: any) => !isResolvedStatus(item.status))
            .map((item: any) => ({
              id: item.id,
              title: item.title || "Untitled",
              location: item.location_lost || "Unknown location",
              type: "lost" as const,
              image_urls: item.image_urls,
              created_at: item.created_at,
              status: item.status,
            }))
          );
        }

        if (!foundRes.error && foundRes.data) {
          items.push(
            ...foundRes.data
            .filter((item: any) => !isResolvedStatus(item.status))
            .map((item: any) => ({
              id: item.id,
              title: item.title || "Untitled",
              location: item.location_found || "Unknown location",
              type: "found" as const,
              image_urls: item.image_urls,
              created_at: item.created_at,
              status: item.status,
            }))
          );
        }

        // Merge both sources and keep the 5 most recent reports globally.
        const latestItems = items
          .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
          .slice(0, 5);
        setRecentItems(latestItems);
      } catch (err) {
        console.error("Error loading recent items:", err);
        setRecentItems([]);
      } finally {
        setItemsLoading(false);
      }
    };

    loadRecentItems();
  }, [user?.id ?? null, supabase]);

  const handleLogout = async () => {
    setShowLogoutModal(true);
  };

  const confirmLogout = async () => {
    try {
      setIsSigningOut(true);
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      setShowLogoutModal(false);
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
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
          className="w-8 h-8 rounded-full border-2 border-gray-200 border-t-[#203e7e]"
        />
      </div>
    );
  }

  const userName = user.user_metadata?.full_name || user.email?.split("@")[0] || "User";

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col font-sans text-gray-900 pb-20">
      <AppHeader onLogout={handleLogout} />

      {/* Main Content Area */}
      <main className="flex-1 w-full md:max-w-md lg:max-w-lg mx-auto p-4 pt-20">
        
        {/* Welcome Section */}
        <div className="mb-6 mt-2">
          <h2 className="text-xl font-bold text-gray-900 border-b-2 border-[#e31e24] inline-block pb-1 pr-4">
            Hi, {userName}!
          </h2>
          <p className="text-sm text-gray-500 mt-2 font-medium">What are you looking for today?</p>
        </div>

        {/* Action Buttons */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          <button
            onClick={() => router.push(CONFIG.ROUTES.REPORT_LOST)}
            className="bg-white border border-gray-200 shadow-sm rounded-2xl p-4 flex flex-col items-center justify-center gap-3 hover:border-blue-300 hover:shadow-md transition-all active:scale-[0.98] group"
          >
            <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center group-hover:bg-[#203e7e] transition-colors">
              <Package className="w-6 h-6 text-[#203e7e] group-hover:text-white" />
            </div>
            <span className="font-semibold text-sm text-gray-800 tracking-tight">Report Lost</span>
          </button>
          
          <button
            onClick={() => router.push(CONFIG.ROUTES.REPORT_FOUND)}
            className="bg-white border border-gray-200 shadow-sm rounded-2xl p-4 flex flex-col items-center justify-center gap-3 hover:border-red-300 hover:shadow-md transition-all active:scale-[0.98] group"
          >
            <div className="w-12 h-12 rounded-full bg-red-50 flex items-center justify-center group-hover:bg-[#e31e24] transition-colors">
              <MapPin className="w-6 h-6 text-[#e31e24] group-hover:text-white" />
            </div>
            <span className="font-semibold text-sm text-gray-800 tracking-tight">Report Found</span>
          </button>
        </div>

        {/* Recent Items Feed */}
        <div className="mb-4">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold text-gray-900 text-base">Recently Reported</h3>
            <button
              onClick={() => router.push(CONFIG.ROUTES.REPORTED_ITEMS)}
              className="text-[11px] text-[#203e7e] font-bold uppercase tracking-wider hover:underline bg-blue-50 px-2 py-1 rounded"
            >
              View All
            </button>
          </div>
          
          {itemsLoading ? (
            <div className="space-y-3">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="bg-white border border-gray-100 rounded-xl px-3.5 py-3 animate-pulse h-20" />
              ))}
            </div>
          ) : recentItems.length === 0 ? (
            <div className="bg-blue-50 border border-blue-200 rounded-xl px-4 py-4 text-center text-sm text-gray-600">
              No recent items yet. Report your first item to get started!
            </div>
          ) : (
            <div className="space-y-3">
              {recentItems.map((item) => (
                <motion.div
                  key={item.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="bg-white border border-gray-100 rounded-xl px-3.5 py-3 grid grid-cols-[64px_1fr_20px] items-center gap-3 shadow-sm active:scale-[0.99] transition-transform cursor-pointer hover:shadow-md"
                  onClick={() => router.push(`${CONFIG.ROUTES.REPORTED_ITEMS}/${item.type}/${item.id}`)}
                >
                  <div className="w-16 h-16 rounded-lg bg-gray-50 flex-shrink-0 flex items-center justify-center border border-gray-100 overflow-hidden">
                    {item.image_urls && item.image_urls.length > 0 ? (
                      <img
                        src={item.image_urls[0]}
                        alt={item.title}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <Package className="w-7 h-7 text-gray-300" />
                    )}
                  </div>
                  <div className="min-w-0 flex flex-col justify-center gap-1">
                    <div className="flex items-start gap-2">
                      <span
                        className={`text-[9px] font-bold px-2 py-0.5 rounded uppercase tracking-wider ${
                          item.type === "lost"
                            ? "text-white bg-[#e31e24]"
                            : "text-[#203e7e] bg-blue-50 border border-blue-100"
                        }`}
                      >
                        {item.type === "lost" ? "Lost" : "Found"}
                      </span>
                    </div>
                    <h4 className="font-bold text-gray-900 text-sm truncate leading-tight">{item.title}</h4>
                    <p className="text-[11px] text-gray-500 truncate flex items-center gap-1 font-medium">
                      <MapPin className="w-3 h-3 text-gray-400" /> {item.location}
                    </p>
                  </div>
                  <ChevronRight className="w-5 h-5 text-gray-300 justify-self-end" />
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </main>

      <AnimatePresence>
        {showLogoutModal && (
          <>
            <motion.div
              className="fixed inset-0 z-50 bg-black/40 backdrop-blur-[2px]"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => !isSigningOut && setShowLogoutModal(false)}
            />
            <motion.div
              className="fixed inset-0 z-50 flex items-center justify-center p-4"
              initial={{ opacity: 0, scale: 0.96, y: 8 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.96, y: 8 }}
              transition={{ duration: 0.16 }}
            >
              <div className="w-full max-w-sm rounded-2xl bg-white p-5 shadow-2xl border border-gray-100">
                <h3 className="text-base font-bold text-gray-900">Confirm Sign Out</h3>
                <p className="mt-2 text-sm text-gray-500">
                  Are you sure you want to sign out? You will need to log in again.
                </p>
                <div className="mt-5 flex items-center justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => setShowLogoutModal(false)}
                    disabled={isSigningOut}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-semibold text-gray-600 transition-colors hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={confirmLogout}
                    disabled={isSigningOut}
                    className="rounded-lg bg-[#e31e24] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {isSigningOut ? "Signing out..." : "Sign Out"}
                  </button>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
