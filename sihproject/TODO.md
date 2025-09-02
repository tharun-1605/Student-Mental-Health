# TODO: Implement Persistent Login

## Tasks
- [x] Modify main.dart to check authentication state on app start
- [x] Add logic to determine user type (student/mentor) if logged in
- [x] Navigate to appropriate home page if logged in, else show WelcomePage
- [x] Test the implementation by logging in and restarting the app
- [x] Ensure logout functionality works correctly

## Current Status
- Understanding: Firebase Auth persists login by default, but main.dart always shows WelcomePage
- Plan: Use FutureBuilder in main.dart to check currentUser and user type from Firestore
- Completed: Added AuthWrapper widget that checks auth state on app start and navigates to appropriate page

---

# TODO: Add Profile Page to Mentor Home

## Tasks
- [x] Add profile icon to mentor_home.dart appBar
- [x] Modify ProfilePage to handle both students and mentors
- [x] Test profile page navigation from mentor home

## Current Status
- Understanding: Mentor home only had refresh icon, needed profile access like student home
- Plan: Add profile icon to appBar and make ProfilePage generic for both user types
- Completed: Added profile icon and modified ProfilePage to check both 'students' and 'mentors' collections

---

# TODO: Implement FCM Push Notifications

## Tasks
- [x] Create FCM service class with initialization and token management
- [x] Add login notification trigger in login.dart after successful authentication
- [x] Add booking request notification trigger in booking.dart after successful booking
- [x] Update booking.dart to use centralized FCM service
- [x] Test notification triggers for login and booking events

## Current Status
- Understanding: Need to implement push notifications for key events (login, booking requests)
- Plan: Create FCM service, integrate with login and booking flows, trigger Cloud Functions
- Completed:
  - Created FCMService class with initialization, token storage, and notification methods
  - Added login notification trigger in login.dart after successful login
  - Added booking request notification trigger in booking.dart after successful booking
  - Updated booking.dart to use centralized FCM service instead of direct Firebase Messaging calls
  - All notification triggers now create events in Firestore collections that will trigger Cloud Functions
