import express from "express";
import multer from "multer";
import path from "path";
import { spawn } from "child_process";

const router = express.Router();

// ---------------- Existing CSV Upload Code (UNCHANGED) ----------------
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['application/vnd.ms-excel', 'text/csv'];
    if (!allowedTypes.includes(file.mimetype)) {
      return cb(new Error('Invalid file type. Only CSV files are allowed.'));
    }
    cb(null, true);
  }
});

// =========================================
// 1️⃣ YOUR OLD ROUTE — KEEP THIS
// =========================================
router.post('/upload', upload.fields([{ name: 'items' }, { name: 'transactions' }]), (req, res) => {
  if (!req.files.items || !req.files.transactions) {
    return res.status(400).json({ error: 'Both CSV files are required' });
  }

  const premiumSlots = req.body.premiumSlots;
  if (!premiumSlots || isNaN(premiumSlots) || Number(premiumSlots) <= 0) {
    return res.status(400).json({ error: 'Invalid number of premium slots.' });
  }

  console.log('Received Premium Slots:', premiumSlots);

  const itemsPath = path.resolve('./uploads/', req.files.items[0].filename);
  const transactionsPath = path.resolve('./uploads/', req.files.transactions[0].filename);

  const pythonProcess = spawn('python3', ['scripts/script.py', itemsPath, transactionsPath, premiumSlots]);

  let output = '';
  pythonProcess.stdout.on('data', (data) => {
    output += data.toString();
    console.log(`Python stdout: ${data}`);
  });

  pythonProcess.stderr.on('data', (data) => {
    console.error(`Python error: ${data}`);
  });

  pythonProcess.on('close', (code) => {
    console.log(`Python process exited with code ${code}`);
    if (code === 0) {
      res.json({ message: 'Processing complete', output });
    } else {
      res.status(500).json({ error: `Python script execution failed with exit code ${code}` });
    }
  });
});

// =========================================
// 2️⃣ NEW: HEATMAP GENERATION ROUTE
// =========================================

const heatmapStorage = multer.diskStorage({
  destination: "./uploads/",
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});

const heatmapUpload = multer({
  storage: heatmapStorage,
  limits: { fileSize: 15 * 1024 * 1024 }
});

// --- Heatmap Route ---
router.post(
  "/generate-heatmap",
  heatmapUpload.fields([
    { name: "layout", maxCount: 1 },
    { name: "arrangement", maxCount: 1 },
    { name: "transactions", maxCount: 1 }
  ]),
  (req, res) => {

    // Still verify uploads (optional)
    if (!req.files.layout || !req.files.arrangement || !req.files.transactions) {
      return res.status(400).json({ error: "3 files required: layout, arrangement, transactions" });
    }

    // 👉 You do NOT pass paths or JSON — Python already knows where to read files
    const python = spawn("python3", ["scripts/generate_heatmap.py"]);

    let output = "";

    python.stdout.on("data", (data) => {
      output += data.toString();
    });

    python.stderr.on("data", (data) => {
      console.error("Python error:", data.toString());
    });

    python.on("close", (code) => {
      if (code !== 0) {
        return res.status(500).json({ error: "Python script failed" });
      }
      res.json({ image: output });
    });
  }
);

export default router;
