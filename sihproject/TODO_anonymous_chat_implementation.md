# TODO: Anonymous Chat Implementation

## Current Status
- File is incomplete - missing State class and state variables
- Methods are incorrectly defined in StatefulWidget class
- Need to implement persistent chat storage and WhatsApp-style UI

## Implementation Steps

### 1. Fix File Structure
- [ ] Create proper State class with all state variables
- [ ] Move methods to State class
- [ ] Add missing imports and lifecycle methods

### 2. Add Persistent Chat Storage
- [ ] Add state variables for loaded messages from Firestore
- [ ] Implement method to load messages for selected mentor
- [ ] Add real-time listener for message updates
- [ ] Update message display to include loaded messages

### 3. Implement WhatsApp-Style UI
- [ ] Add state management for current view (mentor list vs chat)
- [ ] Create mentor list view as initial screen
- [ ] Create chat view that opens when mentor is selected
- [ ] Add back navigation from chat to mentor list
- [ ] Add smooth transitions between views

### 4. Update Message Handling
- [ ] Load existing messages when mentor is selected
- [ ] Sync new messages in real-time
- [ ] Handle message ordering by timestamp
- [ ] Update local message display logic

### 5. Testing and Validation
- [ ] Test message persistence across app sessions
- [ ] Verify real-time message syncing
- [ ] Test UI transitions and navigation
- [ ] Test mentor selection and chat opening

## State Variables Needed
- TextEditingController _messageController
- FocusNode _focusNode
- ScrollController _scrollController
- AnimationController _fadeController, _slideController, _sendController, _successController
- List<Map<String, dynamic>> _sentMessages
- List<Map<String, dynamic>> _mentors
- String? _selectedMentorId, _selectedMentorName, _studentCollege
- bool _isLoadingMentors, _isSending
- int _maxLength
- StreamSubscription? _messagesSubscription
- bool _showChatView (for WhatsApp style)

## Key Methods to Implement
- initState() - Initialize controllers and load mentors
- _loadMentors() - Load mentors from Firestore
- _loadMessages() - Load messages for selected mentor
- _setupMessageListener() - Set up real-time listener
- _sendMessage() - Send message and update local state
- _buildMentorList() - WhatsApp-style mentor list
- _buildChatView() - Chat interface
- dispose() - Clean up controllers and listeners
