const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendMessageNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const messageData = snapshot.data();
      if (!messageData) return null;

      const senderId = messageData.senderId;
      const receiverId = messageData.receiverId;
      const messageText = messageData.message || "Sent a media file";

      // Prevent self-notifications
      if (senderId === receiverId) return null;

      // Get receiver's FCM token
      const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
      if (!receiverDoc.exists) {
        console.log("Receiver user does not exist");
        return null;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      if (!fcmToken) {
        console.log("No FCM token found for user: " + receiverId);
        return null;
      }

      // Get sender's name
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      let senderName = "Someone";
      if (senderDoc.exists) {
        senderName = senderDoc.data().name || "Someone";
      }

      // Build notification payload
      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: messageText,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          chatId: context.params.chatId,
          senderId: senderId,
        },
        android: {
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        const response = await admin.messaging().send(payload);
        console.log("Push notification sent successfully to " + receiverId, response);
        return response;
      } catch (error) {
        console.error("Error sending push notification:", error);
        return null;
      }
    });
