import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import cookieParser from "cookie-parser";
import fs from "fs";
import path from "path";

import connectDB from "./config/mongodb.js";
import authRouter from "./routes/authRoutes.js";
import userRouter from "./routes/userRoutes.js";
import uploadRouter from "./routes/uploadRoutes.js";
import visualRoute from "./routes/visualRoute.js";

dotenv.config();
connectDB();

const app = express();
const port = process.env.PORT || 5000;

// ======================
// ⭐ MIDDLEWARE
// ======================
app.use(express.json());
app.use(cookieParser());
app.use(
  cors({
    origin: "http://localhost:5173",
    credentials: true,
  })
);

// ======================
// 🟢 TEST ENDPOINT
// ======================
app.get("/", (req, res) => {
  res.send("✅ Server is running successfully!");
});

// ======================
// ⭐ CSV SAVE ENDPOINT
// ======================
app.post("/save-csv", (req, res) => {
  const { items } = req.body;

  if (!items || !Array.isArray(items)) {
    return res.status(400).json({ error: "❌ Invalid or empty items list" });
  }

  const csvData = items.join("\n");

  const filePath = path.join(process.cwd(), "final_list.csv");

  try {
    fs.writeFileSync(filePath, csvData);
    console.log("📁 CSV SAVED:", filePath);

    res.json({
      success: true,
      message: "CSV saved successfully!",
      path: filePath,
    });
  } catch (error) {
    console.error("❌ CSV WRITE ERROR:", error);
    res.status(500).json({ error: "Failed to save CSV" });
  }
});

// ======================
// 🔁 BACKEND RESTART TRACKER
// ======================
const restartFile = path.join(process.cwd(), "restart.log");

app.get("/restart-time", (req, res) => {
  const timestamp = fs.existsSync(restartFile)
    ? fs.readFileSync(restartFile, "utf8")
    : "0";

  res.json({ time: timestamp });
});

// ======================
// 🛣 EXISTING ROUTES
// ======================
// Serve image files
app.use(express.static(process.cwd()));

// Existing routes
app.use("/api/auth", authRouter);
app.use("/api/user", userRouter);
app.use("/api", uploadRouter);
app.use("/api/visual", visualRoute);


// ======================
// 🚀 START SERVER
// ======================
app.listen(port, () => {
  console.log(`🚀 Backend running on port ${port}`);

  // SAVE RESTART TIME
  fs.writeFileSync(restartFile, Date.now().toString());
  console.log("🔄 Restart timestamp updated!");
});