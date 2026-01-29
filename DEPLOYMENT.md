# Awadh Dairy - Deployment Guide

Complete guide to deploy Awadh Dairy on **Vercel** (frontend + API) with **Supabase** (database + auth).

---

## Prerequisites

1. **GitHub account** with the repository
2. **Vercel account** (free tier works)
3. **Supabase account** with a project created

---

## Step 1: Set Up Supabase Database

### 1.1 Run Main Schema
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **SQL Editor** in the left sidebar
4. Copy contents of `supabase/consolidated_schema.sql`
5. Paste and click **Run** (takes ~60 seconds)

### 1.2 Verify Schema
Go to **Table Editor** → You should see 35+ tables created.

---

## Step 2: Create Super Admin User

### 2.1 Create Auth User
1. Go to **Authentication** → **Users**
2. Click **Add User**
3. Enter:
   - **Email**: `7897716792@awadhdairy.com`
   - **Password**: `101101`
4. Click **Create User**
5. **Copy the User ID** (UUID) shown for the new user

### 2.2 Set Up Admin Profile
1. Go to **SQL Editor**
2. Open `supabase/setup_super_admin.sql`
3. Replace `YOUR_USER_ID_HERE` with the UUID you copied
4. Click **Run**

### 2.3 Verify Admin
Go to **Table Editor** → **profiles** → You should see the Super Admin record.

---

## Step 3: Get Supabase Credentials

Go to **Project Settings** → **API** and note:
- **Project URL**: e.g., `https://xxxxx.supabase.co`
- **Anon/Public Key**: `eyJhbGc...` (safe for frontend)
- **Service Role Key**: `eyJhbGc...` (secret, for API only)

---

## Step 4: Deploy to Vercel

### 4.1 Connect Repository
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click **Add New** → **Project**
3. Import your GitHub repository

### 4.2 Configure Build Settings
- **Framework Preset**: Vite
- **Build Command**: `npm run build`
- **Output Directory**: `dist`

### 4.3 Set Environment Variables
Add these environment variables:

| Variable | Value |
|----------|-------|
| `VITE_SUPABASE_URL` | `https://xxxxx.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Your anon key |
| `VITE_SUPABASE_PROJECT_ID` | `xxxxx` |
| `SUPABASE_URL` | Same as VITE_SUPABASE_URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Your service role key |
| `SUPABASE_ANON_KEY` | Your anon key |

### 4.4 Deploy
Click **Deploy** and wait for build to complete.

---

## Step 5: Login to Your App

1. Open your Vercel URL (e.g., `https://awadhdairy.vercel.app`)
2. Navigate to `/auth`
3. Enter:
   - **Phone**: `7897716792`
   - **PIN**: `101101`
4. Click **Sign In**
5. You should be redirected to the dashboard!

---

## Default Super Admin Credentials

| Field | Value |
|-------|-------|
| Phone | 7897716792 |
| PIN | 101101 |
| Email (internal) | 7897716792@awadhdairy.com |
| Role | super_admin |

> **Note**: Change these credentials after first login for security!

---

## Creating Additional Staff Users

After logging in as super admin:
1. Navigate to **Users** in the sidebar
2. Click **Add User**
3. Fill in phone, name, PIN, and select role
4. Click **Create User**

---

## Troubleshooting

### "Invalid login credentials"
- Verify the super admin was created correctly in Supabase
- Check that the password in Auth matches the PIN (101101)
- Ensure profiles and user_roles tables have the admin record

### API errors
- Check Vercel environment variables are set correctly
- Verify SUPABASE_SERVICE_ROLE_KEY is set (not just the anon key)

### RLS permission errors
- Ensure `consolidated_schema.sql` was fully executed
- Check RLS policies exist: Database → Policies

---

## Local Development

```bash
# Clone and install
git clone <your-repo-url>
cd awadhdairy
npm install

# Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials

# Start dev server
npm run dev
```

App runs at `http://localhost:5000`

---

## Tech Stack

- **Frontend**: React 18, Vite, TypeScript, Tailwind CSS, shadcn/ui
- **Backend**: Supabase (PostgreSQL, Auth, RLS)
- **API**: Vercel Serverless Functions
- **Mobile**: Capacitor (Android/iOS ready)
