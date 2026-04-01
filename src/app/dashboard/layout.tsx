import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Dashboard - ReFind UTeM",
  description: "Manage your lost and found items",
};

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
