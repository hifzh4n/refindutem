"use client";

import { useEffect, useMemo, useState } from "react";
import { Bell, ClipboardList, Home, MessageCircle, User } from "lucide-react";
import { usePathname, useRouter } from "next/navigation";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";

const HIDE_ON_ROUTES = ["/", "/sign-in", "/register"];
const NOTIFICATIONS_LAST_SEEN_KEY = "notifications_last_seen_at";

const getLastSeenTimestamp = (): number => {
  if (typeof window === "undefined") {
    return 0;
  }

  const value = window.localStorage.getItem(NOTIFICATIONS_LAST_SEEN_KEY);
  if (!value) {
    return 0;
  }

  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
};

export function BottomNav() {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [hasUnreadNotifications, setHasUnreadNotifications] = useState(false);

  const shouldHideNav = HIDE_ON_ROUTES.includes(pathname);

  const isHome = pathname.startsWith(CONFIG.ROUTES.DASHBOARD);
  const isReportedItems = pathname.startsWith(CONFIG.ROUTES.REPORTED_ITEMS);
  const isChat = pathname.startsWith(CONFIG.ROUTES.CHAT);
  const isNotifications = pathname.startsWith(CONFIG.ROUTES.NOTIFICATIONS);
  const isProfile = pathname.startsWith(CONFIG.ROUTES.PROFILE);

  useEffect(() => {
    const checkUnreadNotifications = async () => {
      if (isNotifications) {
        setHasUnreadNotifications(false);
        if (typeof window !== "undefined") {
          window.localStorage.setItem(NOTIFICATIONS_LAST_SEEN_KEY, new Date().toISOString());
          window.localStorage.setItem("has_unread_notifications", "false");
        }
        return;
      }

      if (typeof window !== "undefined") {
        const cached = window.localStorage.getItem("has_unread_notifications");
        if (cached === "true") {
          setHasUnreadNotifications(true);
        }
        if (cached === "false") {
          setHasUnreadNotifications(false);
        }
      }

      const { data } = await supabase.auth.getUser();
      if (!data.user) {
        setHasUnreadNotifications(false);
        return;
      }

      const hasUnreadByActivity = async (): Promise<boolean> => {
        const lastSeenAt = getLastSeenTimestamp();

        const [lostRes, foundRes] = await Promise.all([
          supabase
            .from("lost_items")
            .select("created_at,updated_at")
            .eq("user_id", data.user.id)
            .order("updated_at", { ascending: false })
            .limit(1),
          supabase
            .from("found_items")
            .select("created_at,updated_at")
            .eq("user_id", data.user.id)
            .order("updated_at", { ascending: false })
            .limit(1),
        ]);

        const candidates = [
          lostRes.data?.[0]?.updated_at,
          lostRes.data?.[0]?.created_at,
          foundRes.data?.[0]?.updated_at,
          foundRes.data?.[0]?.created_at,
        ].filter(Boolean) as string[];

        if (candidates.length === 0) {
          return false;
        }

        const latestActivity = Math.max(...candidates.map((value) => new Date(value).getTime()));
        if (!Number.isFinite(latestActivity)) {
          return false;
        }

        return latestActivity > lastSeenAt;
      };

      const primaryRes = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", data.user.id)
        .eq("is_read", false)
        .limit(1);

      if (!primaryRes.error) {
        const hasUnread = Boolean(primaryRes.data && primaryRes.data.length > 0);
        const fallbackUnread = hasUnread ? false : await hasUnreadByActivity();
        const finalUnread = hasUnread || fallbackUnread;
        setHasUnreadNotifications(finalUnread);
        if (typeof window !== "undefined") {
          window.localStorage.setItem("has_unread_notifications", finalUnread ? "true" : "false");
        }
        return;
      }

      if (!/is_read|column/i.test(primaryRes.error.message)) {
        const fallbackUnread = await hasUnreadByActivity();
        setHasUnreadNotifications(fallbackUnread);
        if (typeof window !== "undefined") {
          window.localStorage.setItem("has_unread_notifications", fallbackUnread ? "true" : "false");
        }
        return;
      }

      const fallbackRes = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", data.user.id)
        .eq("read", false)
        .limit(1);

      const hasUnread = Boolean(fallbackRes.data && fallbackRes.data.length > 0);
      const fallbackUnread = hasUnread ? false : await hasUnreadByActivity();
      const finalUnread = hasUnread || fallbackUnread;
      setHasUnreadNotifications(finalUnread);
      if (typeof window !== "undefined") {
        window.localStorage.setItem("has_unread_notifications", finalUnread ? "true" : "false");
      }
    };

    void checkUnreadNotifications();
  }, [isNotifications, pathname, supabase]);

  useEffect(() => {
    const handleReadAll = () => {
      setHasUnreadNotifications(false);
    };

    const handleNewNotification = () => {
      setHasUnreadNotifications(true);
      if (typeof window !== "undefined") {
        window.localStorage.setItem("has_unread_notifications", "true");
      }
    };

    if (typeof window !== "undefined") {
      window.addEventListener("notifications:read-all", handleReadAll);
      window.addEventListener("notifications:new", handleNewNotification);
    }

    return () => {
      if (typeof window !== "undefined") {
        window.removeEventListener("notifications:read-all", handleReadAll);
        window.removeEventListener("notifications:new", handleNewNotification);
      }
    };
  }, []);

  if (shouldHideNav) {
    return null;
  }

  return (
    <nav className="fixed bottom-3 left-0 right-0 z-40 pb-[env(safe-area-inset-bottom)] px-3 md:max-w-md lg:max-w-lg mx-auto">
      <div className="relative flex items-center justify-around h-[74px] px-2 rounded-3xl bg-white/80 backdrop-blur-xl border border-white/60 shadow-[0_12px_32px_rgba(32,62,126,0.18)] before:absolute before:inset-0 before:rounded-3xl before:bg-[linear-gradient(90deg,rgba(32,62,126,0.08),rgba(227,30,36,0.08))] before:pointer-events-none">
        <button
          onClick={() => router.push(CONFIG.ROUTES.DASHBOARD)}
          className={`relative z-10 flex items-center justify-center w-14 h-12 rounded-2xl transition-all ${
            isHome ? "text-[#203e7e] bg-white shadow-sm" : "text-gray-400 hover:text-gray-600"
          }`}
          aria-label="Dashboard"
        >
          <Home className="w-[22px] h-[22px]" strokeWidth={isHome ? 2.5 : 2} />
        </button>

        <button
          onClick={() => router.push(CONFIG.ROUTES.REPORTED_ITEMS)}
          className={`relative z-10 flex items-center justify-center w-14 h-12 rounded-2xl transition-all ${
            isReportedItems ? "text-[#203e7e] bg-white shadow-sm" : "text-gray-400 hover:text-gray-600"
          }`}
          aria-label="Reported items"
        >
          <ClipboardList className="w-[22px] h-[22px]" strokeWidth={isReportedItems ? 2.5 : 2} />
        </button>

        <div className="relative z-10 w-16 flex justify-center -mt-9">
          <button
            onClick={() => router.push(CONFIG.ROUTES.CHAT)}
            className={`relative rounded-full p-3.5 shadow-[0_12px_26px_rgba(32,62,126,0.5)] active:scale-95 transition-transform flex items-center justify-center border-[5px] border-white/90 before:absolute before:inset-[-8px] before:rounded-full before:bg-blue-400/20 before:blur-md before:-z-10 ${
              isChat
                ? "bg-gradient-to-tr from-[#203e7e] to-[#3972ff] text-white"
                : "bg-gradient-to-tr from-[#8ea4d8] to-[#6d8ddb] text-white"
            }`}
            aria-label="Messages"
          >
            <MessageCircle className="w-6 h-6" strokeWidth={2.5} />
          </button>
        </div>

        <button
          onClick={() => router.push(CONFIG.ROUTES.NOTIFICATIONS)}
          className={`relative z-10 flex items-center justify-center w-14 h-12 rounded-2xl transition-all ${
            isNotifications ? "text-[#203e7e] bg-white shadow-sm" : "text-gray-400 hover:text-gray-600"
          }`}
          aria-label="Notifications"
        >
          <div className="relative">
            <Bell className="w-[22px] h-[22px]" strokeWidth={isNotifications ? 2.5 : 2} />
            {!isNotifications && hasUnreadNotifications ? (
              <span className="absolute -top-0.5 -right-0.5 w-[9px] h-[9px] bg-[#e31e24] rounded-full border-[1.5px] border-white" />
            ) : null}
          </div>
        </button>

        <button
          onClick={() => router.push(CONFIG.ROUTES.PROFILE)}
          className={`relative z-10 flex items-center justify-center w-14 h-12 rounded-2xl transition-all ${
            isProfile ? "text-[#203e7e] bg-white shadow-sm" : "text-gray-400 hover:text-gray-600"
          }`}
          aria-label="Profile"
        >
          <User className="w-[22px] h-[22px]" strokeWidth={isProfile ? 2.5 : 2} />
        </button>
      </div>
    </nav>
  );
}
