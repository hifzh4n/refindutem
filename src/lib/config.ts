/**
 * Application Configuration
 * Centralized configuration for the app
 */

export const CONFIG = {
  APP_NAME: process.env.NEXT_PUBLIC_APP_NAME || "ReFind UTeM",
  
  // Email domains for user role identification
  EMAIL_DOMAINS: {
    STUDENT: process.env.NEXT_PUBLIC_STUDENT_EMAIL_DOMAIN || "student.utem.edu.my",
    STAFF: process.env.NEXT_PUBLIC_STAFF_EMAIL_DOMAIN || "utem.edu.my",
  },

  // Auth configuration
  AUTH: {
    PASSWORD_MIN_LENGTH: 6,
    SESSION_TIMEOUT_MS: 24 * 60 * 60 * 1000, // 24 hours
  },

  // Route configuration
  ROUTES: {
    LOGIN: "/sign-in",
    DASHBOARD: "/dashboard",
    REGISTER: "/register",
    PROFILE: "/profile",
    REPORTED_ITEMS: "/reported-items",
    NOTIFICATIONS: "/notifications",
    REPORT: "/report",
    REPORT_LOST: "/report/lost",
    REPORT_FOUND: "/report/found",
  },

  // Public routes (no auth required)
  PUBLIC_ROUTES: ["/", "/sign-in", "/register"],
} as const;

/**
 * Get user role from email
 */
export const getUserRole = (email?: string): "student" | "staff" => {
  if (!email) return "student";
  return email.includes(CONFIG.EMAIL_DOMAINS.STUDENT) ? "student" : "staff";
};

/**
 * Validate email format
 */
export const isValidEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Generate email from user ID and role
 */
export const generateAuthEmail = (userId: string, role: "student" | "staff"): string => {
  const domain = role === "student" ? CONFIG.EMAIL_DOMAINS.STUDENT : CONFIG.EMAIL_DOMAINS.STAFF;
  return `${userId}@${domain}`;
};
