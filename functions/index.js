const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

admin.initializeApp();
const db = admin.firestore();

const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
const REPORT_FROM_EMAIL = process.env.REPORT_FROM_EMAIL || "noreply@example.com";

if (SENDGRID_API_KEY) {
  sgMail.setApiKey(SENDGRID_API_KEY);
}

// Monthly donation summary on first day of month at 01:00 UTC
exports.monthlyDonationSummary = functions.pubsub
  .schedule("0 1 1 * *")
  .timeZone("UTC")
  .onRun(async () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth(); // 0-11 current month

    const lastMonth = new Date(Date.UTC(year, month - 1, 1));
    const start = new Date(
      Date.UTC(
        lastMonth.getUTCFullYear(),
        lastMonth.getUTCMonth(),
        1
      )
    );
    const end = new Date(
      Date.UTC(
        lastMonth.getUTCFullYear(),
        lastMonth.getUTCMonth() + 1,
        1
      )
    );

    const snapshot = await db
      .collection("donations")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(start))
      .where("date", "<", admin.firestore.Timestamp.fromDate(end))
      .get();

    let totalWeight = 0;
    let count = 0;

    const byStore = {}; // storeName -> total weight
    const byVolunteer = {}; // volunteerName -> total weight
    const storeCounts = {}; // storeName -> number of donations
    const volunteerCounts = {}; // volunteerName -> number of donations

    snapshot.forEach((doc) => {
      const data = doc.data();
      const w = Number(data.weightKg || 0);

      totalWeight += w;
      count += 1;

      const store = (data.storeName || "Unknown").trim();
      const vol = (data.volunteerName || "Unknown").trim();

      // totals
      byStore[store] = (byStore[store] || 0) + w;
      byVolunteer[vol] = (byVolunteer[vol] || 0) + w;

      // counts
      storeCounts[store] = (storeCounts[store] || 0) + 1;
      volunteerCounts[vol] = (volunteerCounts[vol] || 0) + 1;
    });

    const avgWeightPerDonation =
      count > 0 ? totalWeight / count : 0;

    const reportDoc = {
      year: lastMonth.getUTCFullYear(),
      month: lastMonth.getUTCMonth() + 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      totalWeightKg: totalWeight,
      totalDonations: count,
      avgWeightKgPerDonation: avgWeightPerDonation,
      // keep original simple maps for compatibility
      byStore,
      byVolunteer,
      // additional summary data (counts per store/volunteer)
      byStoreDonationCounts: storeCounts,
      byVolunteerDonationCounts: volunteerCounts,
    };

    const reportRef = await db
      .collection("monthlyReports")
      .add(reportDoc);

    const staffSnapshot = await db.collection("staff").get();
    const emails = staffSnapshot.docs
      .map((d) => d.data().email)
      .filter((e) => typeof e === "string" && e.includes("@"));

    if (SENDGRID_API_KEY && emails.length > 0) {
      const lines = [];

      const monthLabel = `${reportDoc.year}-${String(
        reportDoc.month
      ).padStart(2, "0")}`;

      lines.push(`Month: ${monthLabel}`);
      lines.push(`Total donations: ${count}`);
      lines.push(`Total weight: ${totalWeight.toFixed(1)} kg`);
      lines.push(
        `Average weight per donation: ${avgWeightPerDonation.toFixed(
          1
        )} kg`
      );
      lines.push("");

      lines.push("By store:");
      if (Object.keys(byStore).length === 0) {
        lines.push("- (no store data)");
      } else {
        Object.entries(byStore).forEach(([name, w]) => {
          const c = storeCounts[name] || 0;
          const avg = c > 0 ? w / c : 0;
          lines.push(
            `- ${name}: ${c} donations, ${w.toFixed(
              1
            )} kg total, avg ${avg.toFixed(1)} kg`
          );
        });
      }

      lines.push("");
      lines.push("By volunteer:");
      if (Object.keys(byVolunteer).length === 0) {
        lines.push("- (no volunteer data)");
      } else {
        Object.entries(byVolunteer).forEach(([name, w]) => {
          const c = volunteerCounts[name] || 0;
          const avg = c > 0 ? w / c : 0;
          lines.push(
            `- ${name}: ${c} donations, ${w.toFixed(
              1
            )} kg total, avg ${avg.toFixed(1)} kg`
          );
        });
      }

      const msg = {
        to: emails,
        from: REPORT_FROM_EMAIL,
        subject: `FoodLink monthly donation report ${monthLabel}`,
        text: lines.join("\n"),
      };

      await sgMail.sendMultiple(msg);
    }

    console.log("Monthly report saved at", reportRef.id);
    return null;
  });

// Pickup reminders every hour, send 24 hours before start time
exports.pickupReminders = functions.pubsub
  .schedule("0 * * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in25h = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    // We assume schedules have field pickupDate (date) and startTime HH:mm string.
    const snapshot = await db
      .collection("schedules")
      .where("status", "in", ["scheduled", "ready"])
      .get();

    const reminderBatch = db.batch();
    const emailsToSend = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.reminderSent) continue;

      const ts = data.pickupDate;
      if (!ts) continue;
      const date = ts.toDate();
      const [hStr, mStr] = String(data.startTime || "09:00").split(":");
      const h = parseInt(hStr, 10) || 9;
      const m = parseInt(mStr, 10) || 0;

      const pickupDateTime = new Date(
        Date.UTC(
          date.getUTCFullYear(),
          date.getUTCMonth(),
          date.getUTCDate(),
          h,
          m
        )
      );

      if (pickupDateTime >= in24h && pickupDateTime < in25h) {
        const storeId = data.storeId;
        const volunteerId = data.volunteerId;
        const storeName = data.storeName || "Store";
        const volunteerName = data.volunteerName || "Volunteer";

        let storeEmail = null;
        let volunteerEmail = null;

        if (storeId) {
          const storeDoc = await db
            .collection("stores")
            .doc(storeId)
            .get();
          storeEmail = storeDoc.exists ? storeDoc.data().email : null;
        }
        if (volunteerId) {
          const vDoc = await db
            .collection("volunteers")
            .doc(volunteerId)
            .get();
          volunteerEmail = vDoc.exists ? vDoc.data().email : null;
        }

        const subject = "Upcoming FoodLink pickup in 24 hours";
        const textLines = [
          "You have an upcoming FoodLink pickup in about 24 hours.",
          "",
          `Store: ${storeName}`,
          `Volunteer: ${volunteerName}`,
          `Pickup time (approx): ${pickupDateTime.toISOString()}`,
        ];
        const text = textLines.join("\n");

        const recipients = [];
        if (storeEmail && storeEmail.includes("@")) recipients.push(storeEmail);
        if (volunteerEmail && volunteerEmail.includes("@"))
          recipients.push(volunteerEmail);

        if (SENDGRID_API_KEY && recipients.length > 0) {
          emailsToSend.push({
            to: recipients,
            from: REPORT_FROM_EMAIL,
            subject,
            text,
          });
        }

        reminderBatch.update(doc.ref, {
          reminderSent: true,
          reminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await db.collection("notifications").add({
          type: "pickup_reminder",
          scheduleId: doc.id,
          storeId,
          volunteerId,
          storeName,
          volunteerName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    if (SENDGRID_API_KEY && emailsToSend.length > 0) {
      for (const msg of emailsToSend) {
        await sgMail.sendMultiple(msg);
      }
    }

    await reminderBatch.commit();
    return null;
  });
