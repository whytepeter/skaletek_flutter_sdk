# Skaletek KYC Flutter SDK Setup Guide

## Quick Fix for "SessionError: An error occurred"

The error you're seeing is caused by an invalid or expired authentication token. Follow these steps to fix it:

### Step 1: Get Your Authentication Token

1. **Sign up/Login to Skaletek Dashboard**
   - Go to [https://dashboard.skaletek.io](https://dashboard.skaletek.io)
   - Create an account or log in to your existing account

2. **Generate API Token**
   - Navigate to the API/Developer section
   - Generate a new API token for your application
   - Copy the token (it should look like: `sk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)

### Step 2: Update the Configuration

1. **Open the configuration file:**
   ```bash
   lib/src/config/app_config.dart
   ```

2. **Replace the placeholder tokens:**
   ```dart
   class AppConfig {
     // Development token - replace with your actual development token
     static const String devToken = "sk_your_actual_dev_token_here";
     
     // Production token - replace with your actual production token  
     static const String prodToken = "sk_your_actual_prod_token_here";
     
     // Current environment
     static const bool isProduction = false; // Set to true for production
     
     // ... rest of the config
   }
   ```

### Step 3: Test the Integration

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Tap "Start Identity Verification"**
   - The app should now successfully connect to the Skaletek API
   - You should see the verification flow instead of the SessionError

## Environment Configuration

### Development Environment
- Uses `devToken` from the configuration
- Points to development API endpoints
- Set `isProduction = false`

### Production Environment  
- Uses `prodToken` from the configuration
- Points to production API endpoints
- Set `isProduction = true`

## Troubleshooting

### Still getting SessionError?
1. **Check token format:** Tokens should start with `sk_`
2. **Verify token validity:** Test the token in the Skaletek dashboard
3. **Check network:** Ensure your device has internet connectivity
4. **API endpoints:** Verify the API URLs are correct for your environment

### Common Token Issues
- **Expired token:** Generate a new token in the dashboard
- **Invalid permissions:** Ensure your token has the required API permissions
- **Wrong environment:** Use dev token for development, prod token for production

## Support

If you continue to have issues:
- Check the [Skaletek Documentation](https://docs.skaletek.io)
- Contact support at support@skaletek.com
- Create an issue in the GitHub repository

## Security Notes

- Never commit real tokens to version control
- Use environment variables for production deployments
- Rotate tokens regularly for security
- Keep your tokens confidential 