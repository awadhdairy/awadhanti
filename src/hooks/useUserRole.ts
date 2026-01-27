import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Database } from "@/integrations/supabase/types";

type UserRole = Database["public"]["Enums"]["user_role"];

interface UserRoleData {
  role: UserRole | null;
  loading: boolean;
  error: string | null;
  userName: string | null;
}

export function useUserRole(): UserRoleData {
  const [role, setRole] = useState<UserRole | null>(null);
  const [userName, setUserName] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchUserRole = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        
        if (!user) {
          console.log("[useUserRole] No authenticated user found");
          setLoading(false);
          return;
        }

        console.log("[useUserRole] Fetching role for user:", user.id);

        // Use profiles_safe view which has proper RLS policies configured
        // This view is SECURITY DEFINER and bypasses RLS restrictions
        const { data: profileData, error: profileError } = await supabase
          .from("profiles_safe")
          .select("role, full_name")
          .eq("id", user.id)
          .maybeSingle();

        if (profileError) {
          console.error("[useUserRole] Error fetching from profiles_safe:", profileError);
        }

        let fetchedRole: UserRole | null = profileData?.role || null;
        let fetchedName: string | null = profileData?.full_name || null;

        console.log("[useUserRole] profiles_safe result - role:", fetchedRole, "name:", fetchedName);

        // Fallback: check user metadata from auth if profiles_safe didn't return a role
        if (!fetchedRole && user.user_metadata?.role) {
          fetchedRole = user.user_metadata.role as UserRole;
          console.log("[useUserRole] Using role from user metadata:", fetchedRole);
        }

        // Fallback for name from user metadata
        if (!fetchedName && user.user_metadata?.full_name) {
          fetchedName = user.user_metadata.full_name as string;
        }

        console.log("[useUserRole] Final role:", fetchedRole, "userName:", fetchedName);

        setRole(fetchedRole);
        setUserName(fetchedName);
        setError(fetchedRole ? null : "Could not determine user role. Please contact administrator.");
        setLoading(false);
      } catch (err) {
        console.error("[useUserRole] Unexpected error:", err);
        setError("Failed to fetch user role");
        setLoading(false);
      }
    };

    fetchUserRole();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      console.log("[useUserRole] Auth state changed:", event);
      fetchUserRole();
    });

    return () => subscription.unsubscribe();
  }, []);

  return { role, loading, error, userName };
}

// Role-based permission checks
export const rolePermissions = {
  super_admin: {
    canAccessAll: true,
    dashboardType: "admin" as const,
    navSections: ["main", "management", "settings"],
  },
  manager: {
    canAccessAll: true,
    dashboardType: "admin" as const,
    navSections: ["main", "management", "settings"],
  },
  accountant: {
    canAccessAll: false,
    dashboardType: "accountant" as const,
    navSections: ["billing", "expenses", "reports"],
  },
  delivery_staff: {
    canAccessAll: false,
    dashboardType: "delivery" as const,
    navSections: ["deliveries", "customers", "bottles"],
  },
  farm_worker: {
    canAccessAll: false,
    dashboardType: "farm" as const,
    navSections: ["cattle", "production", "health", "inventory"],
  },
  vet_staff: {
    canAccessAll: false,
    dashboardType: "vet" as const,
    navSections: ["cattle", "health"],
  },
  auditor: {
    canAccessAll: false,
    dashboardType: "auditor" as const,
    navSections: ["reports", "expenses", "billing"],
  },
};
