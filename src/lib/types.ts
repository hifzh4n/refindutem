/**
 * Type definitions for Supabase user and app-specific types
 */

export interface UserMetadata {
  full_name?: string;
  user_role?: "student" | "staff";
  avatar_url?: string;
}

export interface AppUser {
  id: string;
  email?: string;
  user_metadata?: UserMetadata;
  created_at?: string;
}

export interface LostItem {
  id: string;
  title: string;
  description: string;
  category: string;
  location_found?: string;
  location_lost?: string;
  date_lost?: string;
  date_found?: string;
  user_id: string;
  status: "open" | "claimed" | "resolved";
  image_urls?: string[];
  created_at: string;
  updated_at: string;
}

export interface UserStats {
  total_lost_items: number;
  total_found_items: number;
  claims_resolved: number;
}
