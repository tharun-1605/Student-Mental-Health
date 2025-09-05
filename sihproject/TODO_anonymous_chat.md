# TODO: Implement Anonymous Two-Way Chat Feature

## Overview
Implement a WhatsApp-like anonymous chat feature where students can chat with their college mentors anonymously, and mentors can view and reply to anonymous student chats.

## Current State
- Students can send anonymous messages to mentors (lib/anonymous_student_to_mentor_chat.dart)
- Mentors can view anonymous messages (lib/mentor_anonymous_messages.dart)
- No two-way chat, no replies, no persistent chat history

## Required Changes

### 1. Update Firestore Data Model
- [ ] Modify 'anonymous_messages' collection structure:
  - Add 'senderType': 'student' or 'mentor'
  - Add 'chatId': consistent ID per student-mentor pair (e.g., anonymousId_mentorId)
  - Ensure 'anonymousId' is fixed per student (not per message)
- [ ] Add 'anonymousId' field to 'students' collection if not exists
- [ ] Update Firestore indexes for new queries

### 2. Update Student Anonymous Chat Page (lib/anonymous_student_to_mentor_chat.dart)
- [ ] Generate and store fixed anonymousId for student
- [ ] Load chat history for selected mentor
- [ ] Display chat bubbles for both sent and received messages
- [ ] Implement real-time message listening
- [ ] Update UI to show chat history instead of just sent messages
- [ ] Add typing indicator and online status if needed

### 3. Update Mentor Anonymous Messages Page (lib/mentor_anonymous_messages.dart)
- [ ] Change from message list to chat list (grouped by chatId/anonymousId)
- [ ] Show list of anonymous student chats with last message preview
- [ ] Add chat UI with reply functionality
- [ ] Implement real-time message updates
- [ ] Add chat bubbles for conversation view
- [ ] Allow mentors to reply anonymously

### 4. Update Student Home Page (lib/student_home.dart)
- [ ] Add navigation to anonymous chat page
- [ ] Update UI to include "Anonymous Chat" option

### 5. Update Mentor Home Page (lib/mentor_home.dart)
- [ ] Add "Anonymous Messages" button in Quick Actions
- [ ] Navigate to updated mentor anonymous messages page

### 6. Add Helper Functions
- [ ] Create utility functions for generating consistent chatId
- [ ] Add functions for real-time message subscriptions
- [ ] Implement message sending with proper error handling

### 7. Testing and Verification
- [ ] Test full chat flow: student sends message, mentor receives, mentor replies, student sees reply
- [ ] Verify anonymity is maintained
- [ ] Test real-time updates
- [ ] Check UI on different screen sizes
- [ ] Verify Firestore security rules allow anonymous chats

## Dependencies
- Firebase Firestore for data storage
- Firebase Auth for user authentication
- Flutter for UI components

## Estimated Effort
- Data model updates: 2 hours
- Student chat UI updates: 4 hours
- Mentor chat UI updates: 4 hours
- Home page updates: 2 hours
- Helper functions: 2 hours
- Testing: 2 hours
- Total: ~16 hours

## Next Steps
1. Start with data model updates
2. Update student chat page
3. Update mentor chat page
4. Update home pages
5. Add helper functions
6. Test thoroughly
