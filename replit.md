# Awadh Dairy Management System

## Overview
Awadh Dairy is a complete dairy management solution built with React, TypeScript, Vite, and Supabase. The application provides features for cattle management, milk production tracking, customer billing, delivery routes, health records, and financial reports.

## Tech Stack
- **Frontend**: React 18 + TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS + shadcn/ui components
- **State Management**: TanStack Query
- **Backend**: Supabase (hosted)
- **API Routes**: Vercel serverless functions (replaces Supabase Edge Functions)
- **Mobile Support**: Capacitor (for native mobile builds)

## Project Structure
```
src/
├── components/    # React UI components
├── hooks/         # Custom React hooks
├── lib/           # Utility functions and helpers
├── pages/         # Page components
└── integrations/  # Supabase client and types

api/
├── create-user.ts     # Create new staff user (super_admin only)
├── delete-user.ts     # Delete staff user (super_admin only)
├── bootstrap-admin.ts # Bootstrap initial admin account
└── customer-auth.ts   # Customer login/register/change-pin
```

## Development
- **Port**: 5000
- **Dev Server**: `npm run dev`
- **Build**: `npm run build`

## API Routes
The application uses Vercel API routes for server-side operations requiring admin privileges:

- **POST /api/create-user** - Creates a new staff user (requires super_admin)
- **POST /api/delete-user** - Deletes a staff user (requires super_admin)
- **POST /api/bootstrap-admin** - Creates initial admin account using environment credentials
- **POST /api/customer-auth** - Handles customer registration, login, and PIN changes

## Environment Variables

### Frontend (VITE_* prefix)
- `VITE_SUPABASE_PROJECT_ID` - Supabase project ID
- `VITE_SUPABASE_URL` - Supabase API URL
- `VITE_SUPABASE_PUBLISHABLE_KEY` - Supabase anon/public key

### Backend (Vercel API routes)
- `SUPABASE_URL` - Supabase API URL (same as VITE_SUPABASE_URL)
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key (SECRET - never expose)
- `BOOTSTRAP_ADMIN_PHONE` - Phone number for bootstrap admin account
- `BOOTSTRAP_ADMIN_PIN` - PIN for bootstrap admin account

## Authentication
- Staff users: Phone + 6-digit PIN authentication via Supabase Auth
- Customers: Phone + 6-digit PIN via customer_accounts table with separate auth flow
- Roles: super_admin, manager, accountant, delivery_staff, farm_worker, vet_staff, auditor

## Deployment
- **Platform**: Vercel (recommended for API routes) or static hosting
- **Build Output**: `dist/` directory
- **Configuration**: `vercel.json` handles API routes and SPA routing

## Recent Changes (January 2026)
- Migrated from Supabase Edge Functions to Vercel API routes
- Removed `supabase/functions/` directory
- Added `api/` directory with TypeScript serverless functions
- Updated all frontend auth calls to use `/api/*` endpoints
