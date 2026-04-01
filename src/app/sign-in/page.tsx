"use client";

import { useState, useMemo } from "react";
import { motion } from "framer-motion";
import { Package, User, Key, Eye, EyeOff, AlertCircle, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "sonner";
import { createClient } from "@/utils/supabase/client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CONFIG, generateAuthEmail } from "@/lib/config";

export default function LoginPage() {
  const [userId, setUserId] = useState("");
  const [role, setRole] = useState<"student" | "staff">("student");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};

    if (!userId.trim()) {
      errors.userId = "User ID is required";
    }
    if (!password) {
      errors.password = "Password is required";
    } else if (password.length < CONFIG.AUTH.PASSWORD_MIN_LENGTH) {
      errors.password = `Password must be at least ${CONFIG.AUTH.PASSWORD_MIN_LENGTH} characters`;
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      toast.error("Please fix the validation errors.");
      return;
    }
    
    setIsLoading(true);
    
    try {
      const loginEmail = generateAuthEmail(userId.trim(), role);
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password,
      });

      if (error) {
        if (error.message.includes("Invalid login credentials")) {
          toast.error("Invalid User ID or password. Please try again.");
        } else if (error.message.includes("email_not_confirmed")) {
          toast.error("Please verify your email before logging in.");
        } else {
          toast.error(error.message || "An error occurred during login.");
        }
      } else {
        const authUser = data.user;
        if (authUser) {
          const matricNumber = authUser.email?.split("@")[0]?.toUpperCase() || userId.trim().toUpperCase();
          const fullName =
            (typeof authUser.user_metadata?.full_name === "string" && authUser.user_metadata.full_name.trim()) ||
            userId.trim().toUpperCase();

          const { error: profileSyncError } = await supabase.from("profiles").upsert(
            {
              id: authUser.id,
              full_name: fullName,
              matric_number: matricNumber,
              avatar_url:
                typeof authUser.user_metadata?.avatar_url === "string" ? authUser.user_metadata.avatar_url : null,
              updated_at: new Date().toISOString(),
            },
            { onConflict: "id" }
          );

          if (profileSyncError) {
            console.warn("Unable to sync profile details:", profileSyncError);
          }
        }

        toast.success("Successfully logged in!");
        router.push(CONFIG.ROUTES.DASHBOARD);
      }
    } catch (err) {
      console.error("Login error:", err);
      toast.error("An unexpected error occurred. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex justify-center">
      {/* Mobile/PWA constrained container */}
      <div className="w-full md:max-w-md lg:max-w-md bg-white min-h-screen shadow-[0_0_40px_-15px_rgba(0,0,0,0.1)] flex flex-col relative overflow-hidden font-sans">
        
        {/* Top Branding Section */}
        <div className="pt-16 pb-12 px-6 flex flex-col items-center justify-center text-center relative z-10 bg-gradient-to-br from-[#203e7e] to-[#1a3268]">
          {/* Decorative background blur blobs */}
          <div className="absolute top-[-20%] left-[-10%] w-48 h-48 bg-white opacity-5 rounded-full blur-3xl"></div>
          <div className="absolute bottom-[-20%] right-[-10%] w-48 h-48 bg-[#e31e24] opacity-20 rounded-full blur-3xl"></div>
          
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.5 }}
            className="w-16 h-16 bg-white rounded-2xl shadow-xl flex items-center justify-center mb-5 z-10"
          >
            <Package className="w-8 h-8 text-[#203e7e]" />
          </motion.div>
          
          <motion.div
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="z-10"
          >
            <h1 className="text-3xl font-bold text-white mb-2 tracking-tight">
              ReFind <span className="text-[#e31e24]">UTeM</span>
            </h1>
            <p className="text-blue-100/80 text-sm max-w-[250px] mx-auto leading-relaxed">
              The centralized lost and found portal for your campus.
            </p>
          </motion.div>
        </div>

        {/* Main Form Area */}
        <motion.div 
          initial={{ y: "10%" }}
          animate={{ y: 0 }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          className="flex-1 bg-white px-6 pt-8 pb-12 rounded-t-[32px] -mt-8 z-20 relative shadow-[0_-10px_40px_rgba(0,0,0,0.1)] flex flex-col"
        >
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Welcome Back</h2>
            <p className="text-sm text-gray-500 mt-1">Sign in to your account</p>
          </div>

          <form onSubmit={handleLogin} className="flex-1 flex flex-col">
            <div className="space-y-5 flex-1">
              
              {/* Role Selection */}
              <div className="space-y-3">
                <Label className="text-xs font-bold text-gray-500 uppercase tracking-wider">I am a</Label>
                <RadioGroup value={role} onValueChange={setRole} className="flex gap-4">
                  <div className="flex-1 relative">
                    <RadioGroupItem value="student" id="role-student" className="peer sr-only" />
                    <Label
                      htmlFor="role-student"
                      className={`flex items-center justify-center py-3 px-4 rounded-xl border-2 font-semibold text-sm cursor-pointer transition-all ${
                        role === "student"
                          ? "border-[#203e7e] bg-blue-50 text-[#203e7e] shadow-sm"
                          : "border-gray-100 bg-gray-50 text-gray-600"
                      }`}
                    >
                      Student
                    </Label>
                  </div>
                  <div className="flex-1 relative">
                    <RadioGroupItem value="staff" id="role-staff" className="peer sr-only" />
                    <Label
                      htmlFor="role-staff"
                      className={`flex items-center justify-center py-3 px-4 rounded-xl border-2 font-semibold text-sm cursor-pointer transition-all ${
                        role === "staff"
                          ? "border-[#203e7e] bg-blue-50 text-[#203e7e] shadow-sm"
                          : "border-gray-100 bg-gray-50 text-gray-600"
                      }`}
                    >
                      Staff
                    </Label>
                  </div>
                </RadioGroup>
              </div>

              {/* User ID */}
              <div className="space-y-1.5">
                <Label htmlFor="userId" className="text-xs font-bold text-gray-500 uppercase tracking-wider">Student / Staff ID</Label>
                <div className="relative group">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                  <Input
                    id="userId"
                    type="text"
                    placeholder={role === "student" ? "e.g. B03210001" : "e.g. S12345"}
                    value={userId}
                    onChange={(e) => {
                      setUserId(e.target.value);
                      setValidationErrors({ ...validationErrors, userId: "" });
                    }}
                    className={`pl-12 h-14 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-base ${
                      validationErrors.userId ? "border-red-500" : ""
                    }`}
                    aria-label="User ID"
                    aria-invalid={!!validationErrors.userId}
                  />
                </div>
                {validationErrors.userId && (
                  <p className="text-xs text-red-500 flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3 h-3" />
                    {validationErrors.userId}
                  </p>
                )}
              </div>

              {/* Password */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Label htmlFor="password" className="text-xs font-bold text-gray-500 uppercase tracking-wider">Password</Label>
                  <button type="button" className="text-xs font-semibold text-[#203e7e] hover:text-[#e31e24] transition-colors">
                    Forgot password?
                  </button>
                </div>
                <div className="relative group">
                  <Key className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                  <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      setValidationErrors({ ...validationErrors, password: "" });
                    }}
                    className={`pl-12 pr-12 h-14 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-base ${
                      validationErrors.password ? "border-red-500" : ""
                    }`}
                    aria-label="Password"
                    aria-invalid={!!validationErrors.password}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                  >
                    {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                  </button>
                </div>
                {validationErrors.password && (
                  <p className="text-xs text-red-500 flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3 h-3" />
                    {validationErrors.password}
                  </p>
                )}
              </div>
            </div>

            <div className="mt-4 pb-safe">
              <Button 
                type="submit" 
                className="w-full h-14 bg-gradient-to-r from-[#203e7e] to-[#1a3268] hover:from-[#1a3268] hover:to-[#11234a] text-white font-bold text-base rounded-xl transition-all shadow-lg shadow-blue-900/20 active:scale-[0.98] group"
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="flex items-center gap-2">
                    <div className="h-5 w-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    Signing In...
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    Sign In
                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                  </span>
                )}
              </Button>
              
              <div className="text-sm font-medium text-center text-gray-500 mt-6">
                Are you a new member?{" "}
                <Link href={CONFIG.ROUTES.REGISTER} className="font-bold text-[#e31e24] hover:text-red-700 transition-colors">
                  Register here
                </Link>
              </div>
            </div>
          </form>
        </motion.div>
      </div>
      <style jsx global>{`
        .pb-safe {
          padding-bottom: env(safe-area-inset-bottom);
        }
      `}</style>
    </div>
  );
}
