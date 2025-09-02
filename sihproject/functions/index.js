const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMentorMessageNotification = functions.firestore
  .document('mentormessages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) {
      console.log('No message data found');
      return null;
    }

    const college = messageData.college;
    const message = messageData.message;
    const mentorId = messageData.mentorId;

    if (!college || !message || !mentorId) {
      console.log('Missing required message fields');
      return null;
    }

    try {
      // Get all students in the college with FCM tokens
      const studentsSnapshot = await admin.firestore()
        .collection('students')
        .where('college', '==', college)
        .where('fcmToken', '!=', null)
        .get();

      if (studentsSnapshot.empty) {
        console.log('No students with FCM tokens found for college:', college);
        return null;
      }

      const tokens = [];
      studentsSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      if (tokens.length === 0) {
        console.log('No valid FCM tokens found');
        return null;
      }

      // Get mentor name
      const mentorDoc = await admin.firestore().collection('mentors').doc(mentorId).get();
      const mentorName = mentorDoc.exists ? mentorDoc.data().name : 'Mentor';

      const payload = {
        notification: {
          title: `Message from ${mentorName}`,
          body: message,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          mentorId: mentorId,
          college: college,
          messageId: context.params.messageId,
        },
      };

      // Send notifications to all tokens
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log('Notifications sent:', response.successCount);
      return null;
    } catch (error) {
      console.error('Error sending notifications:', error);
      return null;
    }
  });
