"use client";

import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { ChevronLeft, Loader2, Send, UserRound } from "lucide-react";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import { AppHeader } from "@/components/app-header";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";

type ProfileRow = {
  id: string;
  full_name: string | null;
  matric_number: string | null;
  avatar_url: string | null;
};

type ChatMessage = {
  id: string;
  conversation_id: string;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
};

type ChatContact = {
  id: string;
  name: string;
  matric: string;
  avatarUrl: string | null;
};

function getInitials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || "U";
}

function getConversationId(userA: string, userB: string): string {
  return [userA, userB].sort().join("__");
}

function formatTime(value: string): string {
  return new Date(value).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export default function ChatPage() {
  const params = useParams<{ id?: string }>();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const otherUserId = typeof params?.id === "string" ? params.id : null;

  const [loading, setLoading] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [sending, setSending] = useState(false);
  const [selfUserId, setSelfUserId] = useState<string | null>(null);
  const [contact, setContact] = useState<ChatContact | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");

  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages]);

  useEffect(() => {
    const initChat = async () => {
      if (!otherUserId) {
        router.push(CONFIG.ROUTES.DASHBOARD);
        return;
      }

      try {
        const { data: authData, error: authError } = await supabase.auth.getUser();
        if (authError || !authData.user) {
          router.push(CONFIG.ROUTES.LOGIN);
          return;
        }

        const currentUserId = authData.user.id;
        if (currentUserId === otherUserId) {
          router.push(CONFIG.ROUTES.PROFILE);
          return;
        }

        setSelfUserId(currentUserId);

        const conversationId = getConversationId(currentUserId, otherUserId);

        const [profileRes, messagesRes] = await Promise.all([
          supabase.from("profiles").select("id,full_name,matric_number,avatar_url").eq("id", otherUserId).maybeSingle(),
          supabase
            .from("chat_messages")
            .select("id,conversation_id,sender_id,receiver_id,content,created_at")
            .eq("conversation_id", conversationId)
            .order("created_at", { ascending: true }),
        ]);

        if (messagesRes.error) {
          throw messagesRes.error;
        }

        const profileData = profileRes.data as ProfileRow | null;
        setContact({
          id: otherUserId,
          name: profileData?.full_name || "UTeM User",
          matric: profileData?.matric_number || "-",
          avatarUrl: profileData?.avatar_url || null,
        });

        setMessages((messagesRes.data || []) as ChatMessage[]);

        const channel = supabase
          .channel(`chat:${conversationId}`)
          .on(
            "postgres_changes",
            {
              event: "INSERT",
              schema: "public",
              table: "chat_messages",
              filter: `conversation_id=eq.${conversationId}`,
            },
            (payload) => {
              const incoming = payload.new as ChatMessage;
              setMessages((prev) => {
                if (prev.some((item) => item.id === incoming.id)) {
                  return prev;
                }
                return [...prev, incoming];
              });
            }
          )
          .subscribe();

        return () => {
          supabase.removeChannel(channel);
        };
      } catch {
        toast.error("Unable to load chat.");
        router.push(CONFIG.ROUTES.DASHBOARD);
      } finally {
        setLoading(false);
      }
    };

    const cleanupPromise = initChat();

    return () => {
      void cleanupPromise.then((cleanup) => {
        if (typeof cleanup === "function") {
          cleanup();
        }
      });
    };
  }, [otherUserId, router, supabase]);

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

  const handleSend = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!selfUserId || !otherUserId) return;

    const content = draft.trim();
    if (!content || sending) return;

    try {
      setSending(true);
      const conversationId = getConversationId(selfUserId, otherUserId);

      const { data, error } = await supabase
        .from("chat_messages")
        .insert({
          conversation_id: conversationId,
          sender_id: selfUserId,
          receiver_id: otherUserId,
          content,
        })
        .select("id,conversation_id,sender_id,receiver_id,content,created_at")
        .single();

      if (error) {
        throw error;
      }

      const inserted = data as ChatMessage;
      setMessages((prev) => (prev.some((item) => item.id === inserted.id) ? prev : [...prev, inserted]));
      setDraft("");
    } catch {
      toast.error("Unable to send message.");
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Loader2 className="w-7 h-7 animate-spin text-[#203e7e]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-28 flex flex-col gap-3 min-h-screen">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => router.back()}
            className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-[#203e7e]/20 bg-white text-[#203e7e] shadow-sm transition hover:bg-[#203e7e]/5"
            aria-label="Back"
          >
            <ChevronLeft className="w-5 h-5" strokeWidth={2.5} />
          </button>

          <div className="flex-1 rounded-xl border border-gray-100 bg-white px-3 py-2 shadow-sm flex items-center gap-3">
            <div className="h-10 w-10 rounded-full overflow-hidden bg-blue-50 text-[#203e7e] border border-blue-100 flex items-center justify-center shrink-0">
              {contact?.avatarUrl ? (
                <img src={contact.avatarUrl} alt={contact.name} className="h-full w-full object-cover" />
              ) : (
                <span className="text-xs font-bold">{getInitials(contact?.name || "UTeM User")}</span>
              )}
            </div>
            <div className="min-w-0">
              <p className="text-sm font-semibold text-gray-900 truncate">{contact?.name || "UTeM User"}</p>
              <p className="text-xs text-gray-500 truncate">Matric: {contact?.matric || "-"}</p>
            </div>
            {contact ? (
              <button
                type="button"
                onClick={() => router.push(`${CONFIG.ROUTES.PROFILE}/${contact.id}`)}
                className="ml-auto h-9 w-9 rounded-full border border-gray-200 bg-white text-gray-600 hover:text-[#203e7e] hover:bg-blue-50 transition inline-flex items-center justify-center"
                aria-label="View profile"
              >
                <UserRound className="w-4 h-4" />
              </button>
            ) : null}
          </div>
        </div>

        <section className="rounded-2xl border border-gray-100 bg-white shadow-sm p-3 flex-1 min-h-[54vh] flex flex-col">
          <div className="flex-1 overflow-y-auto space-y-2 pr-1">
            {messages.length === 0 ? (
              <div className="h-full flex items-center justify-center text-center px-6 text-gray-500 text-sm">
                Start the conversation by sending your first message.
              </div>
            ) : (
              messages.map((message) => {
                const isMine = message.sender_id === selfUserId;
                return (
                  <div key={message.id} className={`flex ${isMine ? "justify-end" : "justify-start"}`}>
                    <div
                      className={`max-w-[78%] rounded-2xl px-3 py-2 ${
                        isMine ? "bg-[#203e7e] text-white rounded-br-md" : "bg-gray-100 text-gray-900 rounded-bl-md"
                      }`}
                    >
                      <p className="text-sm leading-relaxed whitespace-pre-wrap break-words">{message.content}</p>
                      <p className={`mt-1 text-[10px] ${isMine ? "text-blue-100" : "text-gray-500"}`}>
                        {formatTime(message.created_at)}
                      </p>
                    </div>
                  </div>
                );
              })
            )}
            <div ref={endRef} />
          </div>

          <form onSubmit={handleSend} className="mt-3 flex items-center gap-2 border border-gray-200 rounded-xl px-2 py-2">
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Type a message..."
              className="flex-1 bg-transparent px-1 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none"
              maxLength={1000}
            />
            <button
              type="submit"
              disabled={sending || !draft.trim()}
              className="h-9 w-9 rounded-full bg-[#203e7e] text-white inline-flex items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed"
              aria-label="Send message"
            >
              {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            </button>
          </form>
        </section>
      </main>
    </div>
  );
}
