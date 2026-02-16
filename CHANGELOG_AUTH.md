# Authentication System Changelog

## What Changed

###  Replaced HTTP Basic Auth with Session-Based Login

**Before:**
- Annoying browser popup for credentials
- No way to see what credentials were being tried
- Not reading environment variables correctly

**After:**
- Beautiful landing page with login modal
- Session-based authentication (stays logged in for 7 days)
- Environment variables working correctly
- Dev mode logging shows all login attempts with passwords

### 🎨 New Landing Page

Created a stunning landing page at `/` that showcases:
- **Hero section** with clear value proposition
- **Features grid** with 6 key features (Real-Time Monitoring, Share Validation, Profiles, Message Tracing, HTTP API, Documentation)
- **Quick Connect section** with copy-paste Stratum URL and example command
- **Current profile info** showing active settings
- **Login button** in top right (no annoying popup!)

###  Session Management

- **7-day sessions** - Stay logged in for a week
- **Secure cookies** - Encrypted and signed
- **Easy logout** - Button in header
- **Redirect after login** - Goes to dashboard or requested page

###  Dev Mode Logging

In development, login attempts are logged with full details:

```
[info] Login attempt - Username: myadmin, Password: strongpass
[info] Successfully logged in!
```

Failed attempts also logged:
```
[info] Login attempt - Username: wronguser, Password: wrongpass  
[warning] Failed login attempt - Username: wronguser, Password: wrongpass
```

 **Production:** Passwords are never logged in production mode.

## Files Created

1. **lib/stratum_harness_web/live/landing_live.ex**
   - Beautiful landing page
   - Login modal
   - Feature showcase
   - Connection info

2. **lib/stratum_harness_web/controllers/auth_controller.ex**
   - Handles login/logout
   - Logs attempts in dev mode
   - Session management

3. **lib/stratum_harness_web/plugs/auth.ex** (renamed from basic_auth.ex)
   - Session verification
   - Credential checking
   - Redirect to landing if not authenticated

4. **AUTHENTICATION.md**
   - Complete authentication guide
   - Setup instructions
   - Security notes
   - Troubleshooting

5. **CHANGELOG_AUTH.md** (this file)
   - Summary of changes

## Files Modified

1. **lib/stratum_harness_web/router.ex**
   - Changed routes structure
   - Landing page at `/`
   - Dashboard at `/dashboard` (protected)
   - Instructions at `/instructions` (public)
   - Auth routes at `/auth/login` and `/auth/logout`

2. **lib/stratum_harness_web/endpoint.ex**
   - Added 7-day session expiry

3. **config/*.exs files**
   - Username and password from environment variables

## How to Use

### Start with Custom Credentials

```bash
DASHBOARD_USERNAME="myadmin" DASHBOARD_PASSWORD="strongpass" mix phx.server
```

### Visit the Site

1. Open `http://localhost:4000`
2. See the beautiful landing page
3. Click "Login" button (top right)
4. Enter your credentials
5. Get redirected to dashboard

### Check Dev Logs

Watch your terminal to see login attempts:

```
[info] Login attempt - Username: myadmin, Password: strongpass
[info] Successfully logged in!
```

### Session Persistence

- Login once, stay logged in for 7 days
- Close browser, reopen - still logged in
- Click "Logout" to end session immediately

## Testing

Test the system:

```bash
# 1. Start server with custom credentials
DASHBOARD_USERNAME="testuser" DASHBOARD_PASSWORD="testpass" mix phx.server

# 2. Visit http://localhost:4000
# 3. Click "Login"
# 4. Try wrong password first - see it logged
# 5. Try correct password - see it logged and login succeeds
# 6. Navigate to /dashboard - should work
# 7. Click "Logout"
# 8. Try to access /dashboard - redirected to landing page
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DASHBOARD_USERNAME` | `admin` | Login username |
| `DASHBOARD_PASSWORD` | `admin` (dev), `changeme` (prod) | Login password |

## Routes

| Path | Access | Description |
|------|--------|-------------|
| `/` | Public | Landing page with features and login |
| `/instructions` | Public | Miner setup guide |
| `/dashboard` | Protected | Real-time monitoring (requires login) |
| `/auth/login` | POST | Login endpoint |
| `/auth/logout` | GET | Logout endpoint |
| `/api/*` | Public | JSON API endpoints (no auth) |

## Security Improvements

### What's Better

1. **Session-based** instead of sending credentials with every request
2. **7-day sessions** so users don't have to login constantly  
3. **Dev logging** makes debugging authentication easy
4. **Environment variables** work correctly now
5. **Better UX** with modal instead of browser popup

### Production Considerations

For production deployment:
- Always use HTTPS/TLS
- Use strong passwords (32+ characters)
- Consider rate limiting
- Monitor failed login attempts
- Consider 2FA for extra security

## Breaking Changes

### None! 

The environment variable configuration is the same:
- `DASHBOARD_USERNAME` 
- `DASHBOARD_PASSWORD`

Just restart your server and everything works with the new system.

## Upgrade Notes

If you're running the old version:

1. **Stop the server**
2. **Pull the new code**
3. **Start with environment variables:**
   ```bash
   DASHBOARD_PASSWORD="yourpass" mix phx.server
   ```
4. **Visit http://localhost:4000**
5. **Click "Login" and use your credentials**

No data migration needed - sessions are stored in cookies!

## Example Session Flow

```
User visits http://localhost:4000
  ↓
Landing page loads (public, shows features)
  ↓
User clicks "Login" button (top right)
  ↓
Modal appears with login form
  ↓
User enters credentials
  ↓
[DEV MODE] Logs: "Login attempt - Username: admin, Password: admin"
  ↓
Credentials verified 
  ↓
Session cookie set (expires in 7 days)
  ↓
Redirect to /dashboard
  ↓
User sees real-time monitoring
  ↓
User can navigate freely (session persists)
  ↓
After 7 days OR user clicks "Logout"
  ↓
Session cleared, redirect to landing page
```

## Dev Mode vs Production

| Feature | Dev Mode | Production |
|---------|----------|------------|
| Login Logging |  With passwords |  No password logging |
| Default Password | `admin` | `changeme` (requires change) |
| Session Duration | 7 days | 7 days |
| HTTPS Required | No | **YES** |

## Verification Checklist

- [x] Environment variables work correctly
- [x] Landing page loads at `/`
- [x] Login modal appears when clicking "Login"
- [x] Credentials are verified
- [x] Sessions persist for 7 days
- [x] Dev mode logs show username and password
- [x] Logout works correctly
- [x] Protected routes redirect when not logged in
- [x] Public routes accessible without login
- [x] Dashboard requires authentication
- [x] Instructions page is public

## Support

Questions about the new authentication system?
- Read **AUTHENTICATION.md** for detailed guide
- Check **QUICK_START.md** for getting started
- Look at dev logs to debug login issues

---

**Enjoy the new authentication system! **
