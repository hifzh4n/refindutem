"use client";

import { useMemo, useState, type ChangeEvent } from "react";
import { Camera, Loader2, RotateCcw, Save } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AppHeader } from "@/components/app-header";
import { CONFIG } from "@/lib/config";
import { createClient } from "@/utils/supabase/client";

const LOST_CATEGORIES = ["Wallet", "ID Card", "Phone", "Keys", "Bag", "Laptop", "Other"] as const;
const REPORT_IMAGES_BUCKET = process.env.NEXT_PUBLIC_SUPABASE_REPORTS_BUCKET || "report-images";

const getFileExtension = (file: File) => {
  const nameParts = file.name.split(".");
  if (nameParts.length > 1) {
    return nameParts[nameParts.length - 1].toLowerCase();
  }

  if (file.type.includes("/")) {
    return file.type.split("/")[1].toLowerCase();
  }

  return "jpg";
};

export default function ReportLostPage() {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<string>(LOST_CATEGORIES[0]);
  const [locationLost, setLocationLost] = useState("");
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [isSigningOut, setIsSigningOut] = useState(false);

  const router = useRouter();
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

  const handleCapture = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast.error("Only image capture is supported.");
      event.target.value = "";
      return;
    }

    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }

    setPhotoFile(file);
    setPreviewUrl(URL.createObjectURL(file));
    toast.success("Photo captured. It will be uploaded after submit.");
    event.target.value = "";
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!title.trim() || !locationLost.trim()) {
      toast.error("Please complete all required fields.");
      return;
    }

    try {
      setSubmitting(true);

      const { data: authData, error: authError } = await supabase.auth.getUser();
      if (authError || !authData.user) {
        toast.error("Your session has expired. Please sign in again.");
        router.push(CONFIG.ROUTES.LOGIN);
        return;
      }

      const nowIsoTimestamp = new Date().toISOString();

      const { data: insertedItem, error: insertError } = await supabase
        .from("lost_items")
        .insert({
          user_id: authData.user.id,
          title: title.trim(),
          description: description.trim() || null,
          category,
          location_lost: locationLost.trim(),
          date_lost: nowIsoTimestamp,
          image_urls: null,
          status: "open",
        })
        .select("id")
        .single();

      if (insertError || !insertedItem?.id) {
        toast.error(insertError?.message || "Unable to submit lost item report.");
        return;
      }

      if (photoFile) {
        const extension = getFileExtension(photoFile);
        const filePath = `${authData.user.id}/lost/${insertedItem.id}/${Date.now()}.${extension}`;

        const { error: uploadError } = await supabase.storage
          .from(REPORT_IMAGES_BUCKET)
          .upload(filePath, photoFile, {
            upsert: false,
            contentType: photoFile.type,
          });

        if (uploadError) {
          const reason = uploadError.message ? ` (${uploadError.message})` : "";
          toast.error(`Report submitted, but photo upload failed${reason}`);
          router.push(CONFIG.ROUTES.REPORTED_ITEMS);
          return;
        }

        const { data: publicUrlData } = supabase.storage
          .from(REPORT_IMAGES_BUCKET)
          .getPublicUrl(filePath);

        const publicUrl = publicUrlData.publicUrl;

        if (publicUrl) {
          await supabase
            .from("lost_items")
            .update({ image_urls: [publicUrl], updated_at: new Date().toISOString() })
            .eq("id", insertedItem.id)
            .eq("user_id", authData.user.id);
        }
      }

      toast.success("Lost item report submitted.");
      router.push(CONFIG.ROUTES.REPORTED_ITEMS);
    } catch {
      toast.error("Unexpected error while submitting report.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleReset = () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }

    setTitle("");
    setDescription("");
    setCategory(LOST_CATEGORIES[0]);
    setLocationLost("");
    setPhotoFile(null);
    setPreviewUrl("");
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-24 text-gray-900">
      <AppHeader onLogout={handleLogout} isSigningOut={isSigningOut} />

      <main className="w-full md:max-w-md lg:max-w-lg mx-auto px-4 pt-20 pb-4">
        <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-100 bg-white p-4 shadow-sm space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="lostTitle" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Item Name</Label>
            <Input
              id="lostTitle"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e]"
              placeholder="Example: Dark blue wallet"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="lostCategory" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Category</Label>
            <select
              id="lostCategory"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full h-12 rounded-xl border border-gray-200 bg-gray-50/50 px-3 text-sm outline-none focus:ring-2 focus:ring-[#203e7e]/30"
            >
              {LOST_CATEGORIES.map((option) => (
                <option key={option} value={option}>{option}</option>
              ))}
            </select>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="lostLocation" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Location Lost</Label>
            <Input
              id="lostLocation"
              value={locationLost}
              onChange={(e) => setLocationLost(e.target.value)}
              className="h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e]"
              placeholder="Example: FTMK Lab 1"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="lostDescription" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Description</Label>
            <textarea
              id="lostDescription"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              className="w-full rounded-xl border border-gray-200 bg-gray-50/50 px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#203e7e]/30"
              placeholder="Describe the item details to help others identify it."
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="lostCamera" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Item Photo (Camera Only)</Label>
            <p className="text-xs text-gray-500">Take a live photo on the spot. File and gallery selection are not supported for this flow.</p>
            <input
              id="lostCamera"
              type="file"
              accept="image/*"
              capture="environment"
              onChange={handleCapture}
              className="hidden"
            />
            <label
              htmlFor="lostCamera"
              className="w-full h-11 rounded-xl border border-gray-200 bg-gray-50/60 px-3 text-sm font-semibold text-gray-700 flex items-center justify-center gap-2 cursor-pointer"
            >
              <Camera className="w-4 h-4" />
              {photoFile ? "Retake Photo" : "Snap Photo"}
            </label>
            {previewUrl ? (
              <img
                src={previewUrl}
                alt="Captured item preview"
                className="w-full h-44 rounded-xl object-cover border border-gray-200"
              />
            ) : null}
          </div>

          <Button
            type="submit"
            disabled={submitting}
            className="w-full h-11 rounded-xl bg-[#203e7e] hover:bg-[#1a3268] text-white font-semibold"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            {submitting ? "Submitting..." : "Submit Lost Report"}
          </Button>

          <Button
            type="button"
            variant="outline"
            disabled={submitting}
            onClick={handleReset}
            className="w-full h-11 rounded-xl font-semibold"
          >
            <RotateCcw className="w-4 h-4" />
            Reset
          </Button>
        </form>
      </main>
    </div>
  );
}
