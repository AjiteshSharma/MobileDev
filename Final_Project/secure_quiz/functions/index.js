const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const XLSX = require("xlsx");

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();
const geminiApiKey = defineSecret("GEMINI_API_KEY");

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
    await writeQuestions(questionsRef, parsedQuestions);

    const totalPoints = parsedQuestions.reduce(
      (sum, question) => sum + question.points,
      0
    );

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

exports.generateQuizFromAI = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 300,
    memory: "1GiB",
    secrets: [geminiApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }

    const { uid } = request.auth;
    await assertTeacher(uid);

    const input = normalizeAiQuizRequest(request.data);
    const quizRef = db.collection("quizzes").doc();

    await quizRef.set(
      {
        title: input.title,
        subject: input.subject,
        startAt: admin.firestore.Timestamp.fromDate(input.startAt),
        durationMinutes: input.durationMinutes,
        batch: input.normalizedBatch,
        batchLabel: input.batchLabel,
        createdBy: uid,
        createdByEmail: request.auth.token?.email || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "processing",
        totalQuestions: 0,
        totalPoints: 0,
        source: "ai",
        aiPrompt: input.prompt,
        aiTopics: input.topics,
        aiDifficulty: input.difficulty,
        aiRequestedQuestionCount: input.questionCount,
        aiRequestedMaxMarks: input.maxMarks,
      },
      { merge: true }
    );

    try {
      const generated = await generateQuestionsWithGemini(input);
      const questions = normalizeGeneratedQuestions(
        generated.questions,
        input.questionCount,
        input.maxMarks
      );

      if (questions.length !== input.questionCount) {
        throw new HttpsError(
          "internal",
          "AI generated quiz has an invalid number of questions."
        );
      }

      const questionsRef = quizRef.collection("questions");
      await clearCollection(questionsRef);
      await writeQuestions(questionsRef, questions);

      const totalPoints = questions.reduce(
        (sum, question) => sum + question.points,
        0
      );

      await quizRef.set(
        {
          title: generated.title || input.title,
          status: "ready",
          totalQuestions: questions.length,
          totalPoints,
          parsedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          aiGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
          aiModel: generated.model,
        },
        { merge: true }
      );

      logger.info("AI quiz generated successfully", {
        quizId: quizRef.id,
        totalQuestions: questions.length,
        totalPoints,
      });

      return {
        quizId: quizRef.id,
        totalQuestions: questions.length,
        totalPoints,
      };
    } catch (error) {
      await quizRef.set(
        {
          status: "error",
          errorCode: "ai-generation-failed",
          errorMessage: safeErrorMessage(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      throw error;
    }
  }
);

async function assertTeacher(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  const role = (userDoc.data()?.role || "").toString().toLowerCase();

  if (role !== "teacher") {
    throw new HttpsError(
      "permission-denied",
      "Only teacher accounts can create quizzes."
    );
  }
}

function normalizeAiQuizRequest(data) {
  const title = (data?.title || "").toString().trim();
  const subject = (data?.subject || "").toString().trim();
  const batchLabel = (data?.batch || "").toString().trim();
  const prompt = (data?.prompt || "").toString().trim();
  const difficulty = normalizeDifficulty((data?.difficulty || "").toString());
  const questionCount = parsePositiveInt(
    data?.questionCount,
    "Question count must be between 2 and 50.",
    2,
    50
  );
  const maxMarks = parsePositiveInt(
    data?.maxMarks,
    "Max marks must be between 2 and 500.",
    2,
    500
  );
  const durationMinutes = parsePositiveInt(
    data?.durationMinutes,
    "Duration must be between 1 and 600 minutes.",
    1,
    600
  );

  if (!title) {
    throw new HttpsError("invalid-argument", "Quiz title is required.");
  }
  if (!subject) {
    throw new HttpsError("invalid-argument", "Subject is required.");
  }
  if (!batchLabel) {
    throw new HttpsError("invalid-argument", "Batch is required.");
  }
  if (!prompt) {
    throw new HttpsError("invalid-argument", "Prompt is required.");
  }
  if (maxMarks < questionCount) {
    throw new HttpsError(
      "invalid-argument",
      "Max marks must be at least the question count."
    );
  }

  const topics = extractTopics(prompt);
  if (topics.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Provide at least one topic (comma-separated is supported)."
    );
  }

  const normalizedBatch = normalizeBatch(batchLabel);
  if (!normalizedBatch) {
    throw new HttpsError("invalid-argument", "Batch is required.");
  }

  const startAtMillis = Number(data?.startAtMillis);
  if (!Number.isFinite(startAtMillis)) {
    throw new HttpsError("invalid-argument", "Invalid quiz start time.");
  }
  const startAt = new Date(startAtMillis);
  if (Number.isNaN(startAt.getTime())) {
    throw new HttpsError("invalid-argument", "Invalid quiz start time.");
  }

  return {
    title,
    subject,
    batchLabel,
    normalizedBatch,
    prompt,
    topics,
    difficulty,
    questionCount,
    maxMarks,
    durationMinutes,
    startAt,
  };
}

async function generateQuestionsWithGemini(input) {
  const apiKey = geminiApiKey.value();
  if (!apiKey || !apiKey.trim()) {
    throw new HttpsError(
      "failed-precondition",
      "GEMINI_API_KEY is not configured in Firebase Functions secrets."
    );
  }

  const model = process.env.GEMINI_MODEL || "gemini-2.0-flash";
  const quizSchema = {
    type: "object",
    additionalProperties: false,
    propertyOrdering: ["title", "questions"],
    required: ["title", "questions"],
    properties: {
      title: { type: "string", minLength: 3 },
      questions: {
        type: "array",
        minItems: input.questionCount,
        maxItems: input.questionCount,
        items: {
          type: "object",
          additionalProperties: false,
          propertyOrdering: ["text", "options", "correctOptionIndex", "points"],
          required: ["text", "options", "correctOptionIndex", "points"],
          properties: {
            text: { type: "string", minLength: 6 },
            options: {
              type: "array",
              minItems: 4,
              maxItems: 4,
              items: { type: "string", minLength: 1 },
            },
            correctOptionIndex: {
              type: "integer",
              minimum: 0,
              maximum: 3,
            },
            points: { type: "integer", minimum: 1 },
          },
        },
      },
    },
  };

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [{ text: buildAiPrompt(input) }],
        },
      ],
      generationConfig: {
        temperature: 0.3,
        responseMimeType: "application/json",
        responseJsonSchema: quizSchema,
      },
    }),
  });

  const json = await response.json().catch(() => null);
  if (!response.ok) {
    const details =
      json && typeof json === "object" ? JSON.stringify(json) : "";
    logger.error("Gemini API call failed", {
      status: response.status,
      details: details.slice(0, 600),
    });
    throw new HttpsError(
      "resource-exhausted",
      `Gemini generation failed (${response.status}).`
    );
  }

  const blockReason = (json?.promptFeedback?.blockReason || "")
    .toString()
    .trim();
  if (blockReason) {
    throw new HttpsError(
      "failed-precondition",
      `Gemini blocked the request: ${blockReason}`
    );
  }

  const parts = json?.candidates?.[0]?.content?.parts;
  const content = Array.isArray(parts)
    ? parts
        .map((part) => (part?.text || "").toString())
        .join("")
        .trim()
    : "";
  if (!content) {
    throw new HttpsError("internal", "Gemini returned empty content.");
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    throw new HttpsError(
      "internal",
      "Gemini output could not be parsed as JSON."
    );
  }

  const questions = Array.isArray(parsed?.questions) ? parsed.questions : [];
  return {
    title: (parsed?.title || "").toString().trim(),
    questions,
    model: (json?.modelVersion || model).toString(),
  };
}

function buildAiPrompt(input) {
  const topicLines = input.topics.map((topic, index) => `${index + 1}) ${topic}`);
  return [
    "Generate a multiple-choice quiz.",
    `Subject: ${input.subject}`,
    `Difficulty: ${input.difficulty}`,
    "Focus topics (from teacher input):",
    ...topicLines,
    `Number of questions: ${input.questionCount}`,
    `Total maximum marks: ${input.maxMarks}`,
    "Instructions:",
    "1) Keep questions concise and clear.",
    "2) Each question must have exactly 4 options.",
    "3) Provide one correct option index from 0 to 3.",
    "4) Use integer points per question.",
    "5) Avoid duplicate questions.",
  ].join("\n");
}

function extractTopics(prompt) {
  return prompt
    .split(/[,\n]+/)
    .map((topic) => topic.trim())
    .filter((topic) => topic.length > 0);
}

function normalizeGeneratedQuestions(rawQuestions, expectedCount, maxMarks) {
  if (!Array.isArray(rawQuestions) || rawQuestions.length === 0) {
    throw new HttpsError("internal", "AI did not generate any questions.");
  }

  const cleaned = [];
  for (const raw of rawQuestions) {
    const text = (raw?.text || "").toString().trim();
    if (!text) {
      continue;
    }

    const rawOptions = Array.isArray(raw?.options) ? raw.options : [];
    const options = rawOptions
      .map((option) => option.toString().trim())
      .filter((option) => option.length > 0)
      .slice(0, 4);

    while (options.length < 4) {
      options.push(`Option ${options.length + 1}`);
    }

    const rawIndex = Number(raw?.correctOptionIndex);
    const validIndex =
      Number.isInteger(rawIndex) && rawIndex >= 0 && rawIndex < options.length
        ? rawIndex
        : 0;
    const correctOption = options[validIndex];
    const points = Number(raw?.points);

    cleaned.push({
      text,
      options,
      correctOption,
      points: Number.isFinite(points) && points > 0 ? Math.round(points) : 1,
    });
  }

  if (cleaned.length < expectedCount) {
    throw new HttpsError(
      "internal",
      `AI generated ${cleaned.length} valid questions, expected ${expectedCount}.`
    );
  }

  const trimmed = cleaned.slice(0, expectedCount);
  return rebalancePoints(trimmed, maxMarks);
}

function rebalancePoints(questions, maxMarks) {
  const total = questions.reduce((sum, q) => sum + q.points, 0);
  if (total === maxMarks) {
    return questions;
  }

  const count = questions.length;
  const base = Math.floor(maxMarks / count);
  const remainder = maxMarks % count;

  return questions.map((question, index) => ({
    ...question,
    points: base + (index < remainder ? 1 : 0),
  }));
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

async function writeQuestions(questionsRef, questions) {
  let batch = db.batch();
  let opCount = 0;

  for (let i = 0; i < questions.length; i += 1) {
    const question = questions[i];
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
    if (opCount >= 450) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }
}

function parsePositiveInt(value, errorMessage, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  const rounded = Math.round(parsed);
  if (rounded < min || rounded > max) {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  return rounded;
}

function normalizeBatch(value) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function normalizeDifficulty(value) {
  const normalized = value.trim().toLowerCase();
  if (normalized === "easy" || normalized === "medium" || normalized === "hard") {
    return normalized;
  }
  return "medium";
}

function safeErrorMessage(error) {
  if (error instanceof HttpsError) {
    return error.message;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return "Unknown error";
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
