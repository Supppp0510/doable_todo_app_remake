const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.dailyReminder = functions.pubsub
  .schedule("0 0 * * *") // jalan setiap jam 00:00
  .timeZone("Asia/Jakarta")
  .onRun(async () => {

    const db = admin.firestore();
    const today = new Date();

    const targetDate = new Date();
    targetDate.setDate(today.getDate() + 3); // H-3

    // Normalisasi ke awal hari
    targetDate.setHours(0, 0, 0, 0);

    const tomorrow = new Date(targetDate);
    tomorrow.setDate(targetDate.getDate() + 1);

    // Ambil task dengan deadline H-3
    const snapshot = await db.collection("tasks")
      .where("deadline", ">=", targetDate)
      .where("deadline", "<", tomorrow)
      .get();

    if (snapshot.empty) return null;

    snapshot.forEach(async (doc) => {
      const task = doc.data();
      const uid = task.uid;

      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) return;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return;

      const message = {
        token: fcmToken,
        notification: {
          title: "Reminder Tugas",
          body: `Tugas "${task.title}" akan jatuh tempo dalam 3 hari.`,
        },
        android: {
          priority: "high",
        },
      };

      await admin.messaging().send(message);
    });

    return null;
  });
