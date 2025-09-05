# TODO: Implement Anonymous Messaging Features

## Overview
Enable anonymous messaging for students to send messages to mentors and peer support community spaces with hidden identities.

## Steps

### 1. Create Anonymous Student-to-Mentor Chat Page
- [x] Create `lib/anonymous_student_to_mentor_chat.dart`
- [x] Implement UI for students to send anonymous messages to their mentors
- [x] Use Firestore collection 'anonymous_messages' with fields: mentorId, message, timestamp, anonymousId
- [x] Generate anonymousId for each message to ensure anonymity
- [x] Add option to select mentor from available mentors in the same college

### 2. Create Peer Support Forum Page
- [ ] Create `lib/peer_support_forum.dart`
- [ ] Implement group chat UI for anonymous student interactions
- [ ] Use Firestore collection 'peer_support_messages' with fields: message, timestamp, anonymousId, college
- [ ] Display messages with anonymous identifiers (e.g., "Anonymous User 1")
- [ ] Ensure real identities are hidden

### 3. Create Mentor Anonymous Messages Page
- [ ] Create `lib/mentor_anonymous_messages.dart`
- [ ] Implement UI for mentors to view anonymous messages from students
- [ ] Display messages without student identifiers
- [ ] Allow mentors to respond anonymously if needed

### 4. Update Student Home Page
- [ ] Update `lib/student_home.dart` to navigate to anonymous chat and peer support pages
- [ ] Replace TODO in Peer Support Forum card with actual navigation
- [ ] Add new card for Anonymous Mentor Chat

### 5. Update Mentor Home Page
- [ ] Update `lib/mentor_home.dart` to add button for viewing anonymous messages
- [ ] Add "Anonymous Messages" action in the Quick Actions grid

### 6. Update Firestore Indexes (if needed)
- [ ] Check and update `firestore.indexes.json` for new collections
- [ ] Ensure proper indexing for queries on mentorId, college, timestamp

### 7. Test and Verify
- [ ] Test anonymous messaging from student to mentor
- [ ] Test peer support forum chat
- [ ] Verify anonymity (no identifiable student info stored)
- [ ] Test mentor view of anonymous messages
