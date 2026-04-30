const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const XLSX = require("xlsx");

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

exports.parseQuizExcel = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }

    const { uid } = request.auth;
    await assertTeacher(uid);

    const quizId = (request.data?.quizId || "").toString().trim();
    const storagePath = (request.data?.storagePath || "").toString().trim();

    if (!quizId || !storagePath) {
      throw new HttpsError(
        "invalid-argument",
        "Both quizId and storagePath are required."
      );
    }

    const quizRef = db.collection("quizzes").doc(quizId);
    const quizSnap = await quizRef.get();

    if (!quizSnap.exists) {
      throw new HttpsError("not-found", "Quiz document not found.");
    }

    const quizData = quizSnap.data() || {};
    if (quizData.createdBy !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the quiz owner can parse this file."
      );
    }

    await quizRef.set(
      {
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const [buffer] = await storage.bucket().file(storagePath).download();
    const workbook = XLSX.read(buffer, { type: "buffer" });

    const firstSheetName = workbook.SheetNames?.[0];
    if (!firstSheetName) {
      throw new HttpsError("invalid-argument", "No worksheet found in file.");
    }

    const worksheet = workbook.Sheets[firstSheetName];
    const rows = XLSX.utils.sheet_to_json(worksheet, { defval: "" });

    if (!Array.isArray(rows) || rows.length === 0) {
      throw new HttpsError("invalid-argument", "Uploaded sheet has no rows.");
    }

    const parsedQuestions = [];
    rows.forEach((row, index) => {
      const question = normalizeQuestionRow(row, index + 1);
      if (question) {
        parsedQuestions.push(question);
      }
    });

    if (parsedQuestions.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "No valid question rows were found."
      );
    }

    const questionsRef = quizRef.collection("questions");
    await clearCollection(questionsRef);

    let totalPoints = 0;
    let batch = db.batch();
    let opCount = 0;

    for (let i = 0; i < parsedQuestions.length; i += 1) {
      const question = parsedQuestions[i];
      totalPoints += question.points;

      const docRef = questionsRef.doc();
      batch.set(docRef, {
        text: question.text,
        options: question.options,
        correctOption: question.correctOption,
        points: question.points,
        order: i,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      opCount += 1;
      if (opCount === 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    await quizRef.set(
      {
        status: "ready",
        totalQuestions: parsedQuestions.length,
        totalPoints,
        parsedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info("Excel parsed successfully", {
      quizId,
      totalQuestions: parsedQuestions.length,
    });

    return {
      quizId,
      totalQuestions: parsedQuestions.length,
      totalPoints,
    };
  }
);

async function assertTeacher(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  const role = (userDoc.data()?.role || "").toString().toLowerCase();

  if (role !== "teacher") {
    throw new HttpsError(
      "permission-denied",
      "Only teacher accounts can create quizzes from Excel."
    );
  }
}

function normalizeQuestionRow(row, rowNumber) {
  const rawQuestion =
    row.question || row.Question || row.question_text || row["Question"];
  const questionText = String(rawQuestion || "").trim();

  if (!questionText) {
    return null;
  }

  const optionA = String(row.optionA || row.OptionA || row.A || "").trim();
  const optionB = String(row.optionB || row.OptionB || row.B || "").trim();
  const optionC = String(row.optionC || row.OptionC || row.C || "").trim();
  const optionD = String(row.optionD || row.OptionD || row.D || "").trim();

  const options = [optionA, optionB, optionC, optionD].filter((opt) => opt);
  if (options.length < 2) {
    logger.warn("Skipping question due to missing options", { rowNumber });
    return null;
  }

  const rawCorrect = String(
    row.correctOption || row.CorrectOption || row.correct || row.Answer || ""
  )
    .trim()
    .toUpperCase();

  let correctOption = "";
  if (["A", "B", "C", "D"].includes(rawCorrect)) {
    const idx = rawCorrect.charCodeAt(0) - 65;
    correctOption = options[idx] || options[0];
  } else {
    const exact = options.find(
      (opt) => opt.toLowerCase() === rawCorrect.toLowerCase()
    );
    correctOption = exact || options[0];
  }

  const pointsRaw = Number(row.points || row.Points || row.mark || row.marks || 1);
  const points = Number.isFinite(pointsRaw) && pointsRaw > 0 ? pointsRaw : 1;

  return {
    text: questionText,
    options,
    correctOption,
    points,
  };
}

async function clearCollection(collectionRef) {
  while (true) {
    const snapshot = await collectionRef.limit(400).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    if (snapshot.size < 400) {
      break;
    }
  }
}