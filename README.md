# Awadh Dairy - Complete Dairy Farm Management Solution

A comprehensive dairy farm management system built with React, TypeScript, and Supabase.

## 🚀 Features

- **Cattle Management**: Track cattle, breeding records, health, and lineage
- **Milk Production**: Record daily milk yields with quality metrics
- **Customer Management**: Subscriptions, deliveries, and billing
- **Employee Management**: Attendance, shifts, and payroll
- **Financial Tracking**: Invoices, payments, expenses, and ledgers
- **Delivery Routes**: Optimize delivery with route management
- **Customer Portal**: Self-service app for customers

## 🛠️ Tech Stack

- **Frontend**: React 18, TypeScript, Tailwind CSS, shadcn/ui
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions)
- **Deployment**: Vercel (Frontend) + Supabase (Backend)

## 📋 Deployment Guide

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for complete free-tier deployment instructions.

### Quick Start

```bash
# Clone and install
git clone <your-repo-url>
cd awadh-dairy
npm install

# Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials

# Run locally
npm run dev
```

### Environment Variables

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key
VITE_SUPABASE_PROJECT_ID=your-project-id
```

## 🔐 Security Features

- **PIN-Based Authentication**: 6-digit PIN with bcrypt hashing
- **Role-Based Access Control**: 7 roles with granular permissions
- **Rate Limiting**: Account lockout after 5 failed attempts
- **Row Level Security**: All tables protected with RLS policies
- **Separate Role Storage**: Roles stored in dedicated table (prevents privilege escalation)

## 👤 Initial Setup

1. Deploy to Vercel and Supabase
2. Navigate to `/auth`
3. Enter admin credentials: `7897716792` / `101101`
4. Click "Setup Admin Account"
5. Login and create additional users

## 📁 Project Structure

```
src/
├── components/     # Reusable UI components
├── hooks/          # Custom React hooks
├── pages/          # Route pages
├── lib/            # Utilities
└── integrations/   # Supabase client

supabase/
├── functions/      # Edge functions
├── migrations/     # Database migrations
└── config.toml     # Supabase config
```

## 📄 License

Private - All rights reserved.
