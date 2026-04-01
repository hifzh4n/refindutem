"use client";

import { useEffect, useMemo, useState } from "react";
import { Loader2, MessageCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { AppHeader } from "@/components/app-header";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";

type ProfileRow = {
  id: string;
  full_name: string | null;
  matric_number: string | null;
  avatar_url: string | null;
};

type ChatMessageRow = {
  id: string;
  conversation_id: string;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
};

type ConversationPreview = {
  otherUserId: string;
  name: string;
  avatarUrl: string | null;
  lastMessage: string;
  createdAt: string;
};

function getInitials(name: string): string {
  return (
    name
      .split(" ")
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") || "U"
  );
}

function formatRelativeTime(value: string): string {
  const diffMs = Date.now() - new Date(value).getTime();
  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;

  if (diffMs < minute) return "just now";
  if (diffMs < hour) {
    const mins = Math.floor(diffMs / minute);
    return mins === 1 ? "1 min ago" : `${mins} mins ago`;
  }
  if (diffMs < day) {
    const hours = Math.floor(diffMs / hour);
    return hours === 1 ? "1 hour ago" : `${hours} hours ago`;
  }

  return new Date(value).toLocaleDateString();
}

export default function ChatListPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const [loading, setLoading] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [conversations, setConversations] = useState<ConversationPreview[]>([]);

  useEffect(() => {
    const loadConversations = async () => {
      try {
        const { data: authData, error: authError } = await supabase.auth.getUser();
        if (authError || !authData.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }

        const currentUserId = authData.user.id;

        const { data: rows, error } = await supabase
          .from("chat_messages")
          .select("id,conversation_id,sender_id,receiver_id,content,created_at")
          .or(`sender_id.eq.${currentUserId},receiver_id.eq.${currentUserId}`)
          .order("created_at", { ascending: false });

        if (error) {
          throw error;
        }

        const latestByConversation = new Map<string, ChatMessageRow>();

        for (const row of (rows || []) as ChatMessageRow[]) {
          if (!latestByConversation.has(row.conversation_id)) {
            latestByConversation.set(row.conversation_id, row);
          }
        }

        const previewsSeed = Array.from(latestByConversation.values()).map((row) => ({
          otherUserId: row.sender_id === currentUserId ? row.receiver_id : row.sender_id,
          lastMessage: row.content,
          createdAt: row.created_at,
        }));

        const uniqueUserIds = Array.from(new Set(previewsSeed.map((item) => item.otherUserId)));

        let profileMap = new Map<string, ProfileRow>();

        if (uniqueUserIds.length > 0) {
          const { data: profiles } = await supabase
            .from("profiles")
            .select("id,full_name,matric_number,avatar_url")
            .in("id", uniqueUserIds);

          profileMap = new Map(((profiles || []) as ProfileRow[]).map((profile) => [profile.id, profile]));
        }

        const mapped: ConversationPreview[] = previewsSeed
          .map((seed) => {
            const profile = profileMap.get(seed.otherUserId);
            return {
              otherUserId: seed.otherUserId,
              name: profile?.full_name || "UTeM User",
              avatarUrl: profile?.avatar_url || null,
              lastMessage: seed.lastMessage,
              createdAt: seed.createdAt,
            };
          })
          .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

        setConversations(mapped);
      } finally {
        setLoading(false);
      }
    };

    void loadConversations();
  }, [router, supabase]);

  const handleLogout = async () => {
    try {
      setIsSigningOut(true);
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      router.push(CONFIG.ROUTES.LOGIN);
    } finally {
      setIsSigningOut(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-28">
        <section className="rounded-2xl border border-gray-100 bg-white shadow-sm p-3">
          <h1 className="text-lg font-semibold text-gray-900 px-1">Messages</h1>

          {loading ? (
            <div className="py-14 flex items-center justify-center text-[#203e7e]">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : conversations.length === 0 ? (
            <div className="py-16 px-4 text-center">
              <div className="mx-auto mb-3 h-12 w-12 rounded-full bg-blue-50 text-[#203e7e] border border-blue-100 flex items-center justify-center">
                <MessageCircle className="h-5 w-5" />
              </div>
              <p className="text-sm font-medium text-gray-700">No conversations yet</p>
              <p className="text-xs text-gray-500 mt-1">Open a user profile and tap Message to start chatting.</p>
            </div>
          ) : (
            <div className="mt-3 space-y-2">
              {conversations.map((item) => (
                <button
                  key={item.otherUserId}
                  type="button"
                  onClick={() => router.push(`${CONFIG.ROUTES.CHAT}/${item.otherUserId}`)}
                  className="w-full rounded-xl border border-gray-100 bg-white px-3 py-2 shadow-sm text-left hover:bg-gray-50 transition flex items-center gap-3"
                >
                  <div className="h-11 w-11 rounded-full overflow-hidden bg-blue-50 text-[#203e7e] border border-blue-100 flex items-center justify-center shrink-0">
                    {item.avatarUrl ? (
                      <img src={item.avatarUrl} alt={item.name} className="h-full w-full object-cover" />
                    ) : (
                      <span className="text-xs font-bold">{getInitials(item.name)}</span>
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-sm font-semibold text-gray-900 truncate">{item.name}</p>
                      <span className="text-[11px] text-gray-400 shrink-0">{formatRelativeTime(item.createdAt)}</span>
                    </div>
                    <p className="text-xs text-gray-600 truncate mt-0.5">{item.lastMessage}</p>
                  </div>
                </button>
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
