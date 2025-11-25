# Firestore Security Rules Setup

The ranking system requires specific Firestore security rules to work properly. The rules file `firestore.rules` has been created with the necessary permissions.

## The Problem

You're seeing `PERMISSION_DENIED` errors because the Firestore security rules don't allow:
1. Querying the `users` collection to build leaderboards
2. Reading quiz stats from other users for rankings

## Solution

Deploy the updated security rules to your Firebase project. You have two options:

### Option 1: Deploy via Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`ekitnote`)
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `firestore.rules` file
5. Paste it into the rules editor
6. Click **Publish**

### Option 2: Deploy via Firebase CLI

If you have Firebase CLI installed:

```bash
firebase deploy --only firestore:rules
```

## What the Rules Do

The updated rules allow:
- ✅ **Authenticated users** can read any user document (needed for leaderboards)
- ✅ **Users** can read quiz stats from any user (needed for rankings)
- ✅ **Users** can only write their own quiz stats (security)
- ✅ **Users** can only read/write their own quiz results, notes, and chat history

## Testing

After deploying the rules:
1. Complete a quiz in the app
2. Navigate to the Rankings/Leaderboard page
3. You should see your ranking appear
4. Check the console logs - you should no longer see `PERMISSION_DENIED` errors

## Important Notes

- The rules allow reading user documents for all authenticated users, which is necessary for leaderboards
- Personal data (quiz results, notes, chat history) remains private to each user
- The rules prevent unauthorized writes to other users' data


