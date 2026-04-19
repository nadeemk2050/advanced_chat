/**
 * Advanced Chat — Firebase Cloud Functions
 *
 * 1. onRingSignal   — Sends a high-priority FCM ring notification to the
 *                     receiver whenever a ring_signals document becomes active.
 * 2. onNewMessage  — Sends FCM to the receiver for every new chat message and
 *                     marks the message as "delivered" (double grey ticks).
 *
 * Deploy: firebase deploy --only functions
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp }     = require("firebase-admin/app");
const { getFirestore }       = require("firebase-admin/firestore");
const { getMessaging }       = require("firebase-admin/messaging");

initializeApp();

// ─── 1. Ring notification ──────────────────────────────────────────────────
exports.onRingSignal = onDocumentWritten(
  "ring_signals/{userId}",
  async (event) => {
    const newData = event.data?.after?.data();
    // Only fire when ring becomes active
    if (!newData || !newData.active) return null;

    const receiverId = event.params.userId;
    const senderName = newData.senderName || "Someone";

    const db = getFirestore();
    const userDoc = await db.collection("users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return null;

    try {
      await getMessaging().send({
        token,
        notification: {
          title: `📞 ${senderName} is Calling!`,
          body: "Wake Up! Open the app to respond.",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "ring_channel",
            sound: "default",
            priority: "max",
            visibility: "PUBLIC",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              sound: "default",
              "content-available": 1,
            },
          },
        },
        data: {
          type: "ring",
          senderId:   newData.senderId || "",
          senderName: senderName,
          chatRoomId: newData.chatRoomId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      });
    } catch (err) {
      console.error("Ring FCM error:", err);
    }
    return null;
  }
);

// ─── 2. New message notification + delivered receipt ──────────────────────
exports.onNewMessage = onDocumentWritten(
  "chats/{chatRoomId}/messages/{messageId}",
  async (event) => {
    // Only trigger on document *creation*, not updates
    if (event.data?.before?.exists) return null;

    const message = event.data?.after?.data();
    if (!message) return null;

    const { chatRoomId, messageId } = event.params;
    const senderId = message.senderId;

    // Skip ring type messages (type index 4)
    if (message.type === 4) return null;

    const db = getFirestore();

    // Find the receiver (the other participant)
    const chatDoc = await db.collection("chats").doc(chatRoomId).get();
    const participants = chatDoc.data()?.participants || [];
    const receiverId = participants.find((p) => p !== senderId);
    if (!receiverId) return null;

    const [receiverDoc, senderDoc] = await Promise.all([
      db.collection("users").doc(receiverId).get(),
      db.collection("users").doc(senderId).get(),
    ]);

    const token      = receiverDoc.data()?.fcmToken;
    if (!token) return null;

    const senderName   = senderDoc.data()?.name || "Someone";
    const messageText  = _getPreviewText(message);

    try {
      await getMessaging().send({
        token,
        notification: { title: senderName, body: messageText },
        android: {
          priority: "high",
          notification: {
            channelId: "message_channel",
            sound: "default",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default", "content-available": 1 } },
        },
        data: {
          type:        "message",
          senderId,
          senderName,
          chatRoomId,
          messageId,
          messageText,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      });

      // Mark message as delivered (double grey ticks) now that FCM was sent
      await db
        .collection("chats")
        .doc(chatRoomId)
        .collection("messages")
        .doc(messageId)
        .update({ status: 1 }); // MessageStatus.delivered = 1
    } catch (err) {
      console.error("Message FCM error:", err);
    }
    return null;
  }
);

function _getPreviewText(message) {
  switch (message.type) {
    case 1: return "📷 Photo";
    case 2: return "🎤 Voice note";
    case 3: return "📄 Document";
    default: return message.text || "...";
  }
}
