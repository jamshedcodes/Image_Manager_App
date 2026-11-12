import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { onObjectDeleted } from "firebase-functions/v2/storage";

initializeApp();

const db = getFirestore();
const IMAGES_COLLECTION = "images";
const MAX_BATCH_SIZE = 500;

/**
 * Syncs direct Firebase Storage file deletions (e.g., from Firebase Console)
 * by deleting the corresponding Firestore metadata document(s) matching `storagePath`.
 */
export const syncDeletedStorageObjectToFirestore = onObjectDeleted(
  async (event) => {
    const storagePath = event.data.name;
    if (!storagePath) {
      logger.warn("onObjectDeleted triggered without an object name.");
      return;
    }

    const snapshot = await db
      .collection(IMAGES_COLLECTION)
      .where("storagePath", "==", storagePath)
      .get();

    if (snapshot.empty) {
      logger.info("No Firestore document found for deleted storage object.", {
        storagePath,
      });
      return;
    }

    const docs = snapshot.docs;
    for (let i = 0; i < docs.length; i += MAX_BATCH_SIZE) {
      const batch = db.batch();
      const chunk = docs.slice(i, i + MAX_BATCH_SIZE);
      for (const doc of chunk) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    logger.info("Removed Firestore metadata for deleted storage object.", {
      storagePath,
      deletedCount: docs.length,
    });
  }
);
