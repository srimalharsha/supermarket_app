const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ region: "asia-south1" });

exports.createCustomer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Admin login required.");
  }

  const adminDoc = await admin.firestore().collection("admins").doc(request.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().active === false) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const data = request.data || {};
  const businessName = String(data.businessName || "").trim();
  const ownerName = String(data.ownerName || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "");

  if (!businessName || !ownerName || !email || password.length < 6) {
    throw new HttpsError("invalid-argument", "Business, owner, email and a 6+ character password are required.");
  }

  try {
    const user = await admin.auth().createUser({
      email,
      password,
      displayName: ownerName,
    });

    await admin.firestore().collection("customers").doc(user.uid).set({
      uid: user.uid,
      businessName,
      ownerName,
      email,
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: request.auth.uid,
    });

    return { uid: user.uid };
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "මෙම Email එක දැනටමත් භාවිතා වේ.");
    }
    throw new HttpsError("internal", error.message || "Customer account creation failed.");
  }
});


function sriLankaDateKey() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Colombo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());

  const values = {};
  for (const part of parts) {
    if (part.type !== "literal") values[part.type] = part.value;
  }
  return `${values.year}-${values.month}-${values.day}`;
}

exports.sendPaymentReminders = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Asia/Colombo",
    region: "asia-south1",
  },
  async () => {
    const today = sriLankaDateKey();
    const snapshot = await admin.firestore()
      .collection("notifications")
      .where("paymentDateKey", "==", today)
      .get();

    if (snapshot.empty) {
      console.log("No payment reminders for", today);
      return;
    }

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.sentAt) continue;

      const customerUid = String(data.customerUid || "");
      if (!customerUid) continue;

      const customerDoc = await admin.firestore()
        .collection("customers")
        .doc(customerUid)
        .get();
      const tokens = Array.isArray(customerDoc.data()?.fcmTokens)
        ? customerDoc.data().fcmTokens.filter((t) => typeof t === "string" && t.trim())
        : [];

      if (!tokens.length) {
        console.log("No FCM token for customer", customerUid);
        continue;
      }

      const title = String(data.title || "💳 ගෙවීම් මතක් කිරීම");
      const message = String(data.message || "ඔබගේ ගෙවීම අදට නියමිතයි.");
      const chunks = [];
      for (let i = 0; i < tokens.length; i += 500) {
        chunks.push(tokens.slice(i, i + 500));
      }

      let successCount = 0;
      for (const chunk of chunks) {
        const result = await admin.messaging().sendEachForMulticast({
          tokens: chunk,
          notification: { title, body: message },
          data: {
            type: "payment_reminder",
            notificationId: doc.id,
            paymentDate: String(data.paymentDate || ""),
          },
        });
        successCount += result.successCount;
      }

      if (successCount > 0) {
        await doc.ref.update({
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          sentSuccessCount: successCount,
        });
      }
    }
  }
);
