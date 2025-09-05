# TODO: Fix Anonymous Chat Disappearing Issue

## Steps to Complete
- [ ] Add composite index for 'anonymous_chats' on mentorId (ASC) and timestamp (DESC)
- [ ] Add index for 'anonymous_chats/*/messages' on timestamp (ASC)
- [ ] Deploy indexes to Firestore using 'firebase deploy --only firestore:indexes'
- [ ] Test mentor anonymous chat page to verify chats persist after 1 second
