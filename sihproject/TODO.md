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
