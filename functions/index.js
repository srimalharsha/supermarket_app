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

