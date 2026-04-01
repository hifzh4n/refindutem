"use client";

import { useEffect, useMemo, useState } from "react";
import { motion, useAnimationControls } from "framer-motion";
import { Bell, Loader2, Search, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { createClient } from "@/utils/supabase/client";
import type { AppUser } from "@/lib/types";
import { AppHeader } from "@/components/app-header";

interface Notification {
  id: string;
  message: string;
  type: "item-found" | "item-claimed" | "item-viewed" | "item-resolved" | string;
  read: boolean;
  createdAt: string;
  relatedItemId?: string;
}

type NotificationRow = {
  id: string;
  message: string | null;
  type: string | null;
  is_read?: boolean | null;
  read?: boolean | null;
  created_at: string | null;
  related_item_id?: string | null;
};

type FallbackItemRow = {
  id: string;
  title: string | null;
  status: string | null;
  created_at: string | null;
  updated_at: string | null;
};

type NotificationTypeFilter = "all" | "lost" | "found" | "other";

const NOTIFICATIONS_LAST_SEEN_KEY = "notifications_last_seen_at";
const NOTIFICATIONS_DISMISSED_KEY = "notifications_dismissed_ids";

const getDismissedNotificationIds = (): Set<string> => {
  if (typeof window === "undefined") {
    return new Set();
  }

  try {
    const raw = window.localStorage.getItem(NOTIFICATIONS_DISMISSED_KEY);
    if (!raw) {
      return new Set();
    }
    const parsed = JSON.parse(raw) as string[];
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed);
  } catch {
    return new Set();
  }
};

const persistDismissedNotificationId = (id: string) => {
  if (typeof window === "undefined") {
    return;
  }

  const current = getDismissedNotificationIds();
  current.add(id);
  window.localStorage.setItem(NOTIFICATIONS_DISMISSED_KEY, JSON.stringify(Array.from(current)));
};

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

const formatRelativeTime = (value: string): string => {
  const timestamp = new Date(value).getTime();
  if (Number.isNaN(timestamp)) {
    return "long time ago";
  }

  const diffMs = Date.now() - timestamp;
  const diffSeconds = Math.floor(diffMs / 1000);

  if (diffSeconds < 60) {
    return "just now";
  }

  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes === 1) {
    return "minute ago";
  }
  if (diffMinutes < 60) {
    return `${diffMinutes} minutes ago`;
  }

  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours === 1) {
    return "hour ago";
  }
  if (diffHours < 24) {
    return `${diffHours} hours ago`;
  }

  if (diffHours < 48) {
    return "yesterday";
  }

  const diffDays = Math.floor(diffHours / 24);
  if (diffDays <= 7) {
    return `${diffDays} days ago`;
  }

  return "long time ago";
};

const getNotificationCategory = (notif: Notification): Exclude<NotificationTypeFilter, "all"> => {
  const message = notif.message.toLowerCase();
  const rawType = notif.type.toLowerCase();

  if (rawType.includes("lost") || message.includes(" lost") || message.includes("as lost")) {
    return "lost";
  }

  if (rawType.includes("found") || message.includes(" found") || message.includes("as found")) {
    return "found";
  }

  return "other";
};

function SwipeableNotificationCard({
  notif,
  index,
  onDismiss,
}: {
  notif: Notification;
  index: number;
  onDismiss: (notification: Notification) => void;
}) {
  const controls = useAnimationControls();

  useEffect(() => {
    controls.set({ x: 0, y: 0, opacity: 1 });
  }, [controls]);

  const handleDragEnd = async (_event: MouseEvent | TouchEvent | PointerEvent, info: { offset: { x: number } }) => {
    if (info.offset.x <= -90) {
      await controls.start({ x: -420, opacity: 0, transition: { duration: 0.2 } });
      onDismiss(notif);
      return;
    }

    controls.start({ x: 0, opacity: 1, transition: { type: "spring", stiffness: 450, damping: 35 } });
  };

  return (
    <div className="relative overflow-hidden rounded-lg">
      <div className="absolute inset-0 z-0 pointer-events-none flex items-center justify-end pr-4 bg-red-100 border border-red-200 rounded-lg">
        <span className="text-xs font-semibold text-red-600">Clear</span>
      </div>

      <motion.div
        className={`relative z-10 p-4 rounded-lg border cursor-grab active:cursor-grabbing ${
          notif.read ? "bg-white border-gray-200" : "bg-blue-50 border-blue-200"
        }`}
        initial={{ opacity: 0, y: -10 }}
        animate={controls}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ delay: index * 0.05 }}
        drag="x"
        dragDirectionLock
        dragConstraints={{ left: -140, right: 0 }}
        dragElastic={{ left: 0.08, right: 0 }}
        onDragEnd={handleDragEnd}
      >
        <div className="flex items-center gap-3">
          {!notif.read ? <div className="w-2 h-2 rounded-full mt-2 flex-shrink-0 bg-blue-500" /> : null}
          <div className="flex-1 min-w-0">
            <p className={`text-sm ${notif.read ? "text-gray-700" : "font-semibold text-gray-900"}`}>
              {notif.message}
            </p>
            <div className="flex gap-2 mt-2 flex-wrap">
              <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                {getNotificationCategory(notif).charAt(0).toUpperCase() + getNotificationCategory(notif).slice(1)}
              </span>
            </div>
          </div>
          <span className="text-xs text-gray-400 whitespace-nowrap self-center">{formatRelativeTime(notif.createdAt)}</span>
        </div>
      </motion.div>
    </div>
  );
}

export default function NotificationsPage() {
  const [user, setUser] = useState<AppUser | null>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedType, setSelectedType] = useState<NotificationTypeFilter>("all");
  const [selectedStatus, setSelectedStatus] = useState<"all" | "read" | "unread">("all");

  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const markAllAsSeen = async (userId: string, items: Notification[]) => {
    if (items.length === 0) {
      return;
    }

    const hasUnread = items.some((item) => !item.read);
    if (!hasUnread) {
      return;
    }

    setNotifications(items.map((item) => ({ ...item, read: true })));

    if (typeof window !== "undefined") {
      window.localStorage.setItem(NOTIFICATIONS_LAST_SEEN_KEY, new Date().toISOString());
      window.localStorage.setItem("has_unread_notifications", "false");
      window.dispatchEvent(new CustomEvent("notifications:read-all"));
    }

    const primaryUpdate = await supabase
      .from("notifications")
      .update({ is_read: true })
      .eq("user_id", userId)
      .eq("is_read", false);

    if (primaryUpdate.error && /is_read|column/i.test(primaryUpdate.error.message)) {
      await supabase
        .from("notifications")
        .update({ read: true })
        .eq("user_id", userId)
        .eq("read", false);
    }
  };

  const handleDismissNotification = async (notif: Notification) => {
    setNotifications((prev) => prev.filter((item) => item.id !== notif.id));
    persistDismissedNotificationId(notif.id);

    const isFallbackNotification =
      notif.id.startsWith("lost-reported-") ||
      notif.id.startsWith("lost-resolved-") ||
      notif.id.startsWith("found-reported-") ||
      notif.id.startsWith("found-resolved-");

    if (isFallbackNotification || !user) {
      return;
    }

    const { error } = await supabase
      .from("notifications")
      .delete()
      .eq("id", notif.id)
      .eq("user_id", user.id);

    if (error) {
      console.warn("Failed to delete notification:", error);
    }
  };

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const { data, error } = await supabase.auth.getUser();
        if (error || !data.user) {
          router.push("/sign-in");
          return;
        }
        setUser(data.user as AppUser);
        
        const buildFallbackNotifications = async (): Promise<Notification[]> => {
          const lastSeenAt = getLastSeenTimestamp();
          const fallback: Notification[] = [];
          const [lostRes, foundRes] = await Promise.all([
            supabase
              .from("lost_items")
              .select("id,title,status,created_at,updated_at")
              .eq("user_id", data.user.id)
              .order("created_at", { ascending: false })
              .limit(10),
            supabase
              .from("found_items")
              .select("id,title,status,created_at,updated_at")
              .eq("user_id", data.user.id)
              .order("created_at", { ascending: false })
              .limit(10),
          ]);

          if (!lostRes.error && lostRes.data) {
            (lostRes.data as FallbackItemRow[]).forEach((item) => {
              const createdAt = item.created_at || new Date().toISOString();
              const createdAtMs = new Date(createdAt).getTime();
              fallback.push({
                id: `lost-reported-${item.id}`,
                message: `You reported "${item.title || "Untitled item"}" as lost`,
                type: "lost",
                read: createdAtMs > 0 ? createdAtMs <= lastSeenAt : false,
                createdAt,
                relatedItemId: item.id,
              });

              const status = (item.status || "").toLowerCase();
              if (status === "resolved" || status === "closed") {
                const resolvedAt = item.updated_at || createdAt;
                const resolvedAtMs = new Date(resolvedAt).getTime();
                fallback.push({
                  id: `lost-resolved-${item.id}`,
                  message: `You marked your lost report "${item.title || "Untitled item"}" as solved.`,
                  type: "lost-resolved",
                  read: resolvedAtMs > 0 ? resolvedAtMs <= lastSeenAt : false,
                  createdAt: resolvedAt,
                  relatedItemId: item.id,
                });
              }
            });
          }

          if (!foundRes.error && foundRes.data) {
            (foundRes.data as FallbackItemRow[]).forEach((item) => {
              const createdAt = item.created_at || new Date().toISOString();
              const createdAtMs = new Date(createdAt).getTime();
              fallback.push({
                id: `found-reported-${item.id}`,
                message: `You reported "${item.title || "Untitled item"}" as found`,
                type: "found",
                read: createdAtMs > 0 ? createdAtMs <= lastSeenAt : false,
                createdAt,
                relatedItemId: item.id,
              });

              const status = (item.status || "").toLowerCase();
              if (status === "resolved" || status === "closed") {
                const resolvedAt = item.updated_at || createdAt;
                const resolvedAtMs = new Date(resolvedAt).getTime();
                fallback.push({
                  id: `found-resolved-${item.id}`,
                  message: `You marked your found report "${item.title || "Untitled item"}" as solved.`,
                  type: "found-resolved",
                  read: resolvedAtMs > 0 ? resolvedAtMs <= lastSeenAt : false,
                  createdAt: resolvedAt,
                  relatedItemId: item.id,
                });
              }
            });
          }

          fallback.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
          return fallback.slice(0, 20);
        };

        // Fetch notifications from notifications table first, then fallback to generated ones
        let notifs: Notification[] = [];
        const primaryRes = await supabase
          .from("notifications")
          .select("id,message,type,is_read,created_at,related_item_id")
          .eq("user_id", data.user.id)
          .order("created_at", { ascending: false });

        let notifsData: NotificationRow[] | null = primaryRes.data as NotificationRow[] | null;
        let notifsError = primaryRes.error;

        // Backward compatibility for schemas that still use "read" instead of "is_read".
        // Only retry for unknown-column errors, not permission errors.
        if (notifsError && /is_read|column/i.test(notifsError.message)) {
          const fallbackRes = await supabase
            .from("notifications")
            .select("id,message,type,read,created_at,related_item_id")
            .eq("user_id", data.user.id)
            .order("created_at", { ascending: false });

          notifsData = fallbackRes.data as NotificationRow[] | null;
          notifsError = fallbackRes.error;
        }

        const dismissedIds = getDismissedNotificationIds();

        if (!notifsError && notifsData && notifsData.length > 0) {
          notifs = (notifsData as NotificationRow[]).map((notif) => ({
            id: notif.id,
            message: notif.message || "",
            type: notif.type || "other",
            read: Boolean(notif.is_read ?? notif.read ?? false),
            createdAt: notif.created_at || new Date().toISOString(),
            relatedItemId: notif.related_item_id || undefined,
          }));
        } else {
          notifs = await buildFallbackNotifications();
        }

        if (dismissedIds.size > 0) {
          notifs = notifs.filter((item) => !dismissedIds.has(item.id));
        }

        await markAllAsSeen(data.user.id, notifs);

        if (!notifs.some((item) => !item.read)) {
          setNotifications(notifs);
        }
      } catch (error) {
        console.error("Auth check failed:", error);
        router.push("/sign-in");
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, [supabase, router]);

  // Filter and search notifications
  const filteredNotifications = useMemo(() => {
    return notifications.filter((notif) => {
      const notifCategory = getNotificationCategory(notif);
      const matchesSearch = notif.message.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesType = selectedType === "all" || notifCategory === selectedType;
      const matchesStatus = selectedStatus === "all" || (selectedStatus === "read" ? notif.read : !notif.read);
      return matchesSearch && matchesType && matchesStatus;
    });
  }, [notifications, searchQuery, selectedType, selectedStatus]);

  const handleSignOut = async () => {
    setIsSigningOut(true);
    try {
      await supabase.auth.signOut();
      router.push("/sign-in");
    } catch (error) {
      console.error("Sign out failed:", error);
    } finally {
      setIsSigningOut(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Loader2 className="w-8 h-8 text-[#203e7e] animate-spin" />
      </div>
    );
  }

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <AppHeader isSigningOut={isSigningOut} onLogout={handleSignOut} />
      <main className="pt-20 pb-24 px-4">
        <div className="max-w-md lg:max-w-lg mx-auto space-y-4">
          <h1 className="text-lg font-semibold text-gray-900">Notifications</h1>

          {/* Search Input */}
          <div className="relative">
            <Search className="absolute left-3 top-3 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search notifications..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-3 top-3 text-gray-400 hover:text-gray-600"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Type Filter */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-gray-600 uppercase">Type</label>
            <div className="flex gap-2 flex-wrap">
              {(["all", "lost", "found", "other"] as const).map((type) => (
                <button
                  key={type}
                  onClick={() => setSelectedType(type)}
                  className={`px-3 py-1 text-xs rounded-full transition-colors ${
                    selectedType === type
                      ? "bg-[#203e7e] text-white"
                      : "bg-gray-200 text-gray-700 hover:bg-gray-300"
                  }`}
                >
                  {type === "all" ? "All" : type.charAt(0).toUpperCase() + type.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Status Filter */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-gray-600 uppercase">Status</label>
            <div className="flex gap-2">
              {(["all", "read", "unread"] as const).map((status) => (
                <button
                  key={status}
                  onClick={() => setSelectedStatus(status)}
                  className={`px-3 py-1 text-xs rounded-full transition-colors ${
                    selectedStatus === status
                      ? "bg-[#203e7e] text-white"
                      : "bg-gray-200 text-gray-700 hover:bg-gray-300"
                  }`}
                >
                  {status.charAt(0).toUpperCase() + status.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Notifications List */}
          {filteredNotifications.length > 0 ? (
            <motion.div
              className="space-y-3 mt-6"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
            >
              {filteredNotifications.map((notif, index) => (
                <SwipeableNotificationCard
                  key={notif.id}
                  notif={notif}
                  index={index}
                  onDismiss={handleDismissNotification}
                />
              ))}
            </motion.div>
          ) : (
            <motion.div 
              className="flex flex-col items-center justify-center py-12 md:py-16"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <motion.div 
                className="w-16 h-16 md:w-20 md:h-20 rounded-full bg-gray-100 flex items-center justify-center mb-4"
                animate={{ scale: [1, 1.05, 1] }}
                transition={{ duration: 2, repeat: Infinity }}
              >
                <Bell className="w-8 h-8 md:w-10 md:h-10 text-gray-400" />
              </motion.div>
              <h2 className="text-lg md:text-xl font-semibold text-gray-900 mb-2 text-center">No Notifications</h2>
              <p className="text-sm md:text-base text-gray-500 text-center leading-relaxed px-2">
                {notifications.length === 0 
                  ? "You don't have any notifications yet. When someone interacts with your reports, you'll see notifications here."
                  : "No notifications match your filters."}
              </p>
            </motion.div>
          )}
        </div>
      </main>
    </div>
  );
}
