# Awadh Dairy Management System

## Overview
Awadh Dairy is a complete dairy management solution built with React, TypeScript, Vite, and Supabase. The application provides features for cattle management, milk production tracking, customer billing, delivery routes, health records, and financial reports.

## Tech Stack
- **Frontend**: React 18 + TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS + shadcn/ui components
- **State Management**: TanStack Query
- **Backend**: Supabase (hosted)
- **Mobile Support**: Capacitor (for native mobile builds)

## Project Structure
```
src/
├── components/    # React UI components
├── hooks/         # Custom React hooks
├── lib/           # Utility functions and helpers
├── pages/         # Page components
└── integrations/  # Supabase client and types
```

## Development
- **Port**: 5000
- **Dev Server**: `npm run dev`
- **Build**: `npm run build`

## Environment Variables
- `VITE_SUPABASE_PROJECT_ID` - Supabase project ID
- `VITE_SUPABASE_URL` - Supabase API URL
- `VITE_SUPABASE_PUBLISHABLE_KEY` - Supabase anon/public key

## Deployment
Static deployment with build output in `dist/` directory.
