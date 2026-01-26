# Awadh Dairy - Complete Dairy Management Solution

## Overview
A React + TypeScript dairy management application built with Vite. This is a full-featured dairy management system with cattle management, milk production tracking, customer billing, delivery routes, health records, and financial reports.

## Tech Stack
- **Frontend**: React 18 with TypeScript
- **Build Tool**: Vite 5
- **Styling**: Tailwind CSS with shadcn/ui components
- **Backend**: Supabase (external service)
- **State Management**: TanStack Query

## Project Structure
```
├── src/              # Source code
├── public/           # Static assets
├── supabase/         # Supabase configuration
├── index.html        # Entry HTML file
├── vite.config.ts    # Vite configuration
├── tailwind.config.ts # Tailwind configuration
└── package.json      # Dependencies
```

## Development
- **Start dev server**: `npm run dev`
- **Build**: `npm run build`
- **Port**: 5000 (frontend)

## Environment Variables
- `VITE_SUPABASE_PROJECT_ID` - Supabase project ID
- `VITE_SUPABASE_PUBLISHABLE_KEY` - Supabase anon key
- `VITE_SUPABASE_URL` - Supabase URL

## Recent Changes
- January 26, 2026: Fixed admin user creation bug - added ref-based guards to prevent redirect during user creation, fixed session restoration timing
- January 26, 2026: Created APPLY_FIXES_CRITICAL.sql - simplified SQL script with essential functions for role assignment
- January 26, 2026: Initial Replit setup - configured Vite to use port 5000 with allowedHosts for proxy compatibility

## Known Issues & Fixes
### Admin User Creation (REQUIRES DATABASE FIX)
The frontend fixes are applied, but the database function `admin_create_staff_user` must exist in your Supabase database.
Run `supabase/APPLY_FIXES_CRITICAL.sql` in Supabase Dashboard > SQL Editor to complete the fix.
