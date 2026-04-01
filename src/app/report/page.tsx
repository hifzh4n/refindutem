"use client";

import { useMemo, useState } from "react";
import { ArrowRight, MapPin, Package } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";
import { AppHeader } from "@/components/app-header";

export default function ReportEntryPage() {
  const router = useRouter();
  const [isSigningOut, setIsSigningOut] = useState(false);
  const supabase = useMemo(() => createClient(), []);

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

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-4">
        <section className="rounded-2xl border border-gray-100 bg-white p-5 shadow-sm">
          <h2 className="text-base font-bold text-gray-900">What do you want to report?</h2>
          <p className="mt-1 text-sm text-gray-500">Choose one flow below to continue.</p>

          <div className="mt-4 grid grid-cols-1 gap-3">
            <button
              type="button"
              onClick={() => router.push(CONFIG.ROUTES.REPORT_LOST)}
              className="w-full rounded-2xl border border-blue-100 bg-blue-50/40 px-4 py-4 text-left transition hover:border-blue-300 hover:bg-blue-50"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center border border-blue-100">
                    <Package className="w-5 h-5 text-[#203e7e]" />
                  </div>
                  <div>
                    <p className="text-sm font-bold text-gray-900">Report Lost Item</p>
                    <p className="text-xs text-gray-500">You lost something and need help finding it.</p>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-gray-400" />
              </div>
            </button>

            <button
              type="button"
              onClick={() => router.push(CONFIG.ROUTES.REPORT_FOUND)}
              className="w-full rounded-2xl border border-red-100 bg-red-50/40 px-4 py-4 text-left transition hover:border-red-300 hover:bg-red-50"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center border border-red-100">
                    <MapPin className="w-5 h-5 text-[#e31e24]" />
                  </div>
                  <div>
                    <p className="text-sm font-bold text-gray-900">Report Found Item</p>
                    <p className="text-xs text-gray-500">You found something and want to return it.</p>
                  </div>
                </div>
                <ArrowRight className="w-4 h-4 text-gray-400" />
              </div>
            </button>
          </div>
        </section>
      </main>
    </div>
  );
}
