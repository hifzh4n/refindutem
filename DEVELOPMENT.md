# Development Setup Guide

## Environment Variables

Before running the application, you need to set up environment variables.

### 1. Create a `.env.local` file

Copy the provided `.env.example` file to `.env.local`:

```bash
cp .env.example .env.local
```

### 2. Fill in the Required Variables

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY=your-publishable-key

# App Configuration
NEXT_PUBLIC_APP_NAME=ReFind UTeM
NEXT_PUBLIC_STUDENT_EMAIL_DOMAIN=student.utem.edu.my
NEXT_PUBLIC_STAFF_EMAIL_DOMAIN=utem.edu.my
```

### Getting Supabase Credentials

1. Go to [Supabase](https://supabase.com)
2. Create a new project
3. Go to **Settings → API**
4. Copy the Project URL and anon/public key
5. Paste them into your `.env.local` file

## Architecture & Improvements

### Critical Issues Fixed ✅

1. **Infinite Loop Prevention** - Supabase client creation moved to `useMemo`
2. **Environment Variable Validation** - Proper error handling for missing env vars
3. **Mobile Menu Close Logic** - Menu now closes when items are clicked

### Important Fixes Implemented ✅

1. **Loading States** - Logout button disabled during logout process
2. **Button Navigation** - Action buttons now have proper click handlers
3. **Register Route Protection** - Middleware properly excludes /register as public route
4. **Dashboard SEO** - Added metadata export for proper page title

### Code Quality Improvements ✅

1. **Input Validation** - Email format and password validation on both pages
2. **Error Boundaries** - Global error boundary component to catch runtime errors
3. **Configuration File** - Centralized `lib/config.ts` for all constants
4. **Type Safety** - Proper TypeScript types in `lib/types.ts`
5. **Error Recovery** - Better error messages and user feedback
6. **Accessibility** - ARIA labels and semantic HTML added throughout
7. **Environment Variables** - `.env.example` provided with all required variables

## File Structure

```
src/
├── app/
│   ├── dashboard/
│   │   └── page.tsx          # Protected dashboard page
│   ├── register/
│   │   └── page.tsx          # Registration page
│   ├── page.tsx              # Login page
│   └── layout.tsx            # Root layout with error boundary
├── components/
│   ├── error-boundary.tsx    # Error handling component
│   └── ui/                   # Shadcn UI components
├── lib/
│   ├── config.ts             # Centralized configuration
│   ├── types.ts              # TypeScript type definitions
│   └── utils.ts              # Utility functions
├── utils/
│   └── supabase/
│       ├── client.ts         # Supabase client
│       └── middleware.ts     # Auth middleware
```

## Features

### Authentication
- Email-based authentication with Supabase
- Student and Staff roles
- Session persistence
- Automatic redirects based on auth state

### Dashboard
- Welcome greeting with user info
- Stats cards (placeholder for data integration)
- Quick action cards (Search/Report items)
- Responsive navigation with mobile menu
- Logout functionality

## Security Notes

⚠️ **Important:**
- Never commit `.env.local` to version control
- Keep `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` safe
- All environment variables starting with `NEXT_PUBLIC_` are exposed to the browser

## Running the Application

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm build

# Start production server
npm start
```

Visit [http://localhost:3000](http://localhost:3000) in your browser.

## Testing the Features

### Default Credentials (after setup)
You'll need to create test accounts through the registration page.

### Test Flows
1. **Sign Up** - Create a new student/staff account
2. **Sign In** - Login with created credentials
3. **Dashboard** - View dashboard after successful login
4. **Mobile** - Test responsive design on mobile screens

## Next Steps

Recommended features to implement:
1. Notifications page
2. Settings page  
3. Search functionality page
4. Report item page
5. User profile management
6. Password reset flow
7. Email verification
