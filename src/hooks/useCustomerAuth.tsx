import { useState, useEffect, createContext, useContext } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { User, Session } from '@supabase/supabase-js';

interface CustomerAuthContext {
  user: User | null;
  session: Session | null;
  customerId: string | null;
  customerData: CustomerData | null;
  loading: boolean;
  login: (phone: string, pin: string) => Promise<{ success: boolean; error?: string; pending?: boolean }>;
  register: (phone: string, pin: string) => Promise<{ success: boolean; error?: string; approved?: boolean }>;
  logout: () => Promise<void>;
  changePin: (currentPin: string, newPin: string) => Promise<{ success: boolean; error?: string }>;
  refreshCustomerData: () => Promise<void>;
}

interface CustomerData {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  area: string | null;
  credit_balance: number;
  advance_balance: number;
  subscription_type: string | null;
  billing_cycle: string | null;
}

interface VerifyPinResult {
  customer_id: string;
  user_id: string | null;
  is_approved: boolean;
}

interface RegisterResult {
  success: boolean;
  approved?: boolean;
  error?: string;
  customer_id?: string;
  message?: string;
}

interface ChangePinResult {
  success: boolean;
  error?: string;
  message?: string;
}

const CustomerAuthContext = createContext<CustomerAuthContext | undefined>(undefined);

export function CustomerAuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [customerId, setCustomerId] = useState<string | null>(null);
  const [customerData, setCustomerData] = useState<CustomerData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Set up auth state listener
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        
        if (session?.user?.user_metadata?.is_customer) {
          setCustomerId(session.user.user_metadata.customer_id);
          // Defer data fetch
          setTimeout(() => {
            fetchCustomerData(session.user.user_metadata.customer_id);
          }, 0);
        } else {
          setCustomerId(null);
          setCustomerData(null);
        }
        
        setLoading(false);
      }
    );

    // Check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      
      if (session?.user?.user_metadata?.is_customer) {
        setCustomerId(session.user.user_metadata.customer_id);
        fetchCustomerData(session.user.user_metadata.customer_id);
      }
      
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchCustomerData = async (custId: string) => {
    const { data, error } = await supabase
      .from('customers')
      .select('*')
      .eq('id', custId)
      .single();
    
    if (!error && data) {
      setCustomerData(data);
    }
  };

  const refreshCustomerData = async () => {
    if (customerId) {
      await fetchCustomerData(customerId);
    }
  };

  const login = async (phone: string, pin: string) => {
    try {
      // Step 1: Verify PIN via database function
      const { data: verifyData, error: verifyError } = await supabase.rpc('verify_customer_pin', {
        _phone: phone,
        _pin: pin
      });

      if (verifyError) {
        return { success: false, error: verifyError.message };
      }

      // Check if verification returned a result
      const results = verifyData as VerifyPinResult[] | null;
      if (!results || results.length === 0) {
        return { success: false, error: 'Invalid phone number or PIN' };
      }

      const result = results[0];
      
      // Check if account is approved
      if (!result.is_approved) {
        return { success: false, error: 'Account pending approval', pending: true };
      }

      // Step 2: Login via native Supabase Auth
      const email = `customer_${phone}@awadhdairy.com`;
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password: pin,
      });

      if (authError) {
        // If auth fails but PIN was valid, the auth user might not exist
        // This can happen if the customer was created before auth integration
        console.warn("Auth login failed, customer may need auth account created:", authError.message);
        
        // Try to create the auth user and log in
        const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
          email,
          password: pin,
          options: {
            data: {
              is_customer: true,
              customer_id: result.customer_id,
              phone,
            },
          },
        });

        if (signUpError) {
          return { success: false, error: 'Login failed. Please contact support.' };
        }

        // If sign up succeeded, we should be logged in
        if (signUpData.session) {
          setCustomerId(result.customer_id);
          return { success: true };
        }
      }

      if (authData?.session) {
        setCustomerId(result.customer_id);
      }

      return { success: true };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  };

  const register = async (phone: string, pin: string) => {
    try {
      // Use database function to register customer account
      const { data, error } = await supabase.rpc('register_customer_account', {
        _phone: phone,
        _pin: pin
      });

      if (error) {
        return { success: false, error: error.message };
      }

      const result = data as unknown as RegisterResult;
      if (!result.success) {
        return { success: false, error: result.error };
      }

      // If auto-approved, also create auth user
      if (result.approved && result.customer_id) {
        const email = `customer_${phone}@awadhdairy.com`;
        await supabase.auth.signUp({
          email,
          password: pin,
          options: {
            data: {
              is_customer: true,
              customer_id: result.customer_id,
              phone,
            },
          },
        });
      }

      return { success: true, approved: result.approved };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  };

  const logout = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setSession(null);
    setCustomerId(null);
    setCustomerData(null);
  };

  const changePin = async (currentPin: string, newPin: string) => {
    if (!customerId) {
      return { success: false, error: 'Not logged in' };
    }

    try {
      // Use database function to update PIN
      const { data, error } = await supabase.rpc('update_customer_pin', {
        _customer_id: customerId,
        _current_pin: currentPin,
        _new_pin: newPin
      });

      if (error) {
        return { success: false, error: error.message };
      }

      const result = data as unknown as ChangePinResult;
      if (!result.success) {
        return { success: false, error: result.error };
      }

      // Also update Supabase Auth password for consistency
      const { error: authError } = await supabase.auth.updateUser({
        password: newPin,
      });

      if (authError) {
        console.warn("Auth password update failed (non-critical):", authError.message);
        // Don't fail - PIN hash is the primary auth method
      }

      return { success: true, message: result.message };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  };

  return (
    <CustomerAuthContext.Provider value={{
      user,
      session,
      customerId,
      customerData,
      loading,
      login,
      register,
      logout,
      changePin,
      refreshCustomerData
    }}>
      {children}
    </CustomerAuthContext.Provider>
  );
}

export function useCustomerAuth() {
  const context = useContext(CustomerAuthContext);
  if (context === undefined) {
    throw new Error('useCustomerAuth must be used within a CustomerAuthProvider');
  }
  return context;
}
