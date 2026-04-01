"use client";

import { useState, useMemo } from "react";
import { motion } from "framer-motion";
import { Package, User, Key, Eye, EyeOff, AlertCircle, Type, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "sonner";
import { createClient } from "@/utils/supabase/client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CONFIG, generateAuthEmail } from "@/lib/config";

export default function RegisterPage() {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [userId, setUserId] = useState("");
  const [role, setRole] = useState<"student" | "staff">("student");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};

    if (!firstName.trim()) {
      errors.firstName = "First name is required";
    } else if (firstName.trim().length < 2) {
      errors.firstName = "First name must be at least 2 characters";
    }

    if (!lastName.trim()) {
      errors.lastName = "Last name is required";
    } else if (lastName.trim().length < 2) {
      errors.lastName = "Last name must be at least 2 characters";
    }

    if (!userId.trim()) {
      errors.userId = "User ID is required";
    }

    if (!password) {
      errors.password = "Password is required";
    } else if (password.length < CONFIG.AUTH.PASSWORD_MIN_LENGTH) {
      errors.password = `Password must be at least ${CONFIG.AUTH.PASSWORD_MIN_LENGTH} characters`;
    }

    if (!confirmPassword) {
      errors.confirmPassword = "Please confirm your password";
    } else if (password !== confirmPassword) {
      errors.confirmPassword = "Passwords do not match";
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      toast.error("Please fix the validation errors.");
      return;
    }
    
    setIsLoading(true);
    
    try {
      const registerEmail = generateAuthEmail(userId.trim(), role);
      const fullName = `${firstName.trim()} ${lastName.trim()}`;
      
      const { error } = await supabase.auth.signUp({
        email: registerEmail,
        password,
        options: {
          data: {
            full_name: fullName,
            matric_number: userId.trim().toUpperCase(),
            user_role: role,
          }
        }
      });

      if (error) {
        if (error.message.includes("already registered")) {
          toast.error("This User ID is already registered. Please try another one.");
        } else if (error.message.includes("Invalid email")) {
          toast.error("Invalid User ID format.");
        } else {
          toast.error(error.message || "An error occurred during registration.");
        }
      } else {
        toast.success("Successfully registered! Please log in.");
        router.push(CONFIG.ROUTES.LOGIN);
      }
    } catch (err) {
      console.error("Registration error:", err);
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
        <div className="pt-12 pb-12 px-6 flex flex-col items-center justify-center text-center relative z-10 bg-gradient-to-br from-[#203e7e] to-[#1a3268]">
          <div className="absolute top-[-20%] left-[-10%] w-48 h-48 bg-white opacity-5 rounded-full blur-3xl"></div>
          <div className="absolute bottom-[-20%] right-[-10%] w-48 h-48 bg-[#e31e24] opacity-20 rounded-full blur-3xl"></div>
          
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.5 }}
            className="w-14 h-14 bg-white rounded-2xl shadow-xl flex items-center justify-center mb-4 z-10"
          >
            <Package className="w-7 h-7 text-[#203e7e]" />
          </motion.div>
          
          <motion.div
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="z-10"
          >
            <h1 className="text-2xl font-bold text-white mb-2 tracking-tight">
              Join ReFind <span className="text-[#e31e24]">UTeM</span>
            </h1>
            <p className="text-blue-100/80 text-sm max-w-[250px] mx-auto leading-relaxed">
              Create an account to report or claim lost items securely.
            </p>
          </motion.div>
        </div>

        {/* Main Form Area */}
        <motion.div 
          initial={{ y: "10%" }}
          animate={{ y: 0 }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          className="flex-1 bg-white px-6 pt-8 pb-12 rounded-t-[32px] -mt-6 z-20 relative shadow-[0_-10px_40px_rgba(0,0,0,0.1)] flex flex-col"
        >
          <div className="mb-6">
            <h2 className="text-xl font-bold text-gray-900 tracking-tight">Create Account</h2>
          </div>

          <form onSubmit={handleRegister} className="flex-1 flex flex-col">
            <div className="space-y-4 flex-1">
              
              {/* First Name & Last Name */}
              <div className="grid grid-cols-2 gap-3">
                {/* First Name */}
                <div className="space-y-1.5">
                  <Label htmlFor="firstName" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">First Name</Label>
                  <div className="relative group">
                    <Type className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                    <Input
                      id="firstName"
                      type="text"
                      placeholder="e.g. Ahmad"
                      value={firstName}
                      onChange={(e) => {
                        setFirstName(e.target.value);
                        setValidationErrors({ ...validationErrors, firstName: "" });
                      }}
                      className={`pl-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm ${
                        validationErrors.firstName ? "border-red-500" : ""
                      }`}
                    />
                  </div>
                  {validationErrors.firstName && (
                    <p className="text-xs text-red-500 flex items-center gap-1 mt-1 font-medium">
                      <AlertCircle className="w-3 h-3" />
                      {validationErrors.firstName}
                    </p>
                  )}
                </div>

                {/* Last Name */}
                <div className="space-y-1.5">
                  <Label htmlFor="lastName" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Last Name</Label>
                  <div className="relative group">
                    <Type className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                    <Input
                      id="lastName"
                      type="text"
                      placeholder="e.g. Ali"
                      value={lastName}
                      onChange={(e) => {
                        setLastName(e.target.value);
                        setValidationErrors({ ...validationErrors, lastName: "" });
                      }}
                      className={`pl-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm ${
                        validationErrors.lastName ? "border-red-500" : ""
                      }`}
                    />
                  </div>
                  {validationErrors.lastName && (
                    <p className="text-xs text-red-500 flex items-center gap-1 mt-1 font-medium">
                      <AlertCircle className="w-3 h-3" />
                      {validationErrors.lastName}
                    </p>
                  )}
                </div>
              </div>

              {/* Role Selection */}
              <div className="space-y-2 pt-1">
                <Label className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">I am a</Label>
                <RadioGroup value={role} onValueChange={setRole} className="flex gap-3">
                  <div className="flex-1 relative">
                    <RadioGroupItem value="student" id="role-student" className="peer sr-only" />
                    <Label
                      htmlFor="role-student"
                      className={`flex items-center justify-center py-2.5 px-3 rounded-xl border-2 font-semibold text-sm cursor-pointer transition-all ${
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
                      className={`flex items-center justify-center py-2.5 px-3 rounded-xl border-2 font-semibold text-sm cursor-pointer transition-all ${
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
                <Label htmlFor="userId" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Student / Staff ID</Label>
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
                    className={`pl-12 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm ${
                      validationErrors.userId ? "border-red-500" : ""
                    }`}
                  />
                </div>
                {validationErrors.userId && (
                  <p className="text-xs text-red-500 flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3 h-3" />
                    {validationErrors.userId}
                  </p>
                )}
              </div>

              {/* Multiple fields row (Password & Confirm Password) */}
              <div className="grid grid-cols-2 gap-3">
                {/* Password */}
                <div className="space-y-1.5">
                  <Label htmlFor="password" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Password</Label>
                  <div className="relative group">
                    <Key className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                    <Input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value);
                        setValidationErrors({ ...validationErrors, password: "" });
                      }}
                      className={`pl-9 pr-9 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm ${
                        validationErrors.password ? "border-red-500" : ""
                      }`}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                    >
                      {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {validationErrors.password && (
                    <p className="text-[10px] text-red-500 flex items-start gap-1 mt-1 font-medium leading-tight">
                      <AlertCircle className="w-3 h-3 shrink-0" />
                      {validationErrors.password}
                    </p>
                  )}
                </div>

                {/* Confirm Password */}
                <div className="space-y-1.5">
                  <Label htmlFor="confirmPassword" className="text-[11px] font-bold text-gray-500 uppercase tracking-wider">Confirm</Label>
                  <div className="relative group">
                    <Key className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400 group-focus-within:text-[#203e7e] transition-colors" />
                    <Input
                      id="confirmPassword"
                      type={showPassword ? "text" : "password"}
                      placeholder="••••••••"
                      value={confirmPassword}
                      onChange={(e) => {
                        setConfirmPassword(e.target.value);
                        setValidationErrors({ ...validationErrors, confirmPassword: "" });
                      }}
                      className={`pl-9 pr-9 h-12 rounded-xl bg-gray-50/50 border-gray-200 focus-visible:ring-[#203e7e] focus-visible:ring-offset-0 transition-all text-sm ${
                        validationErrors.confirmPassword ? "border-red-500" : ""
                      }`}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
                      aria-label={showPassword ? "Hide password" : "Show password"}
                    >
                      {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {validationErrors.confirmPassword && (
                    <p className="text-[10px] text-red-500 flex items-start gap-1 mt-1 font-medium leading-tight">
                      <AlertCircle className="w-3 h-3 shrink-0" />
                      {validationErrors.confirmPassword}
                    </p>
                  )}
                </div>
              </div>
            </div>

            <div className="mt-4 pb-safe">
              <Button 
                type="submit" 
                className="w-full h-14 bg-gradient-to-r from-[#e31e24] to-red-700 hover:from-red-700 hover:to-red-800 text-white font-bold text-base rounded-xl transition-all shadow-lg shadow-red-900/20 active:scale-[0.98] group"
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="flex items-center gap-2">
                    <div className="h-5 w-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    Registering...
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    Create Account
                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                  </span>
                )}
              </Button>
              
              <div className="text-sm font-medium text-center text-gray-500 mt-6 pb-2">
                Already have an account?{" "}
                <Link href={CONFIG.ROUTES.LOGIN} className="font-bold text-[#203e7e] hover:text-[#1a3268] transition-colors">
                  Log in here
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
