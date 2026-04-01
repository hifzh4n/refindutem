"use client";

import { LogOut, Package } from "lucide-react";

type AppHeaderProps = {
  onLogout?: () => void;
  isSigningOut?: boolean;
};

export function AppHeader({ onLogout, isSigningOut = false }: AppHeaderProps) {
  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white shadow-sm border-b border-gray-100 flex items-center justify-between px-4 py-3 shrink-0 mx-auto w-full md:max-w-md lg:max-w-lg">
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-lg bg-[#203e7e] flex items-center justify-center shadow-inner">
          <Package className="w-4 h-4 text-white" />
        </div>
        <div>
          <h1 className="font-bold text-[#203e7e] leading-tight flex items-center text-sm">
            ReFind <span className="text-[#e31e24] ml-1">UTeM</span>
          </h1>
          <p className="text-[9px] text-gray-500 font-medium tracking-wide uppercase">Lost & Found</p>
        </div>
      </div>

      {onLogout ? (
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={onLogout}
            disabled={isSigningOut}
            className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-full transition-colors active:scale-95 disabled:opacity-60"
            aria-label="Sign out"
          >
            <LogOut className="w-5 h-5" />
          </button>
        </div>
      ) : (
        <div className="w-9 h-9" aria-hidden="true" />
      )}
    </header>
  );
}
