import fs from "fs";
import path from "path";
import express from "express";

const router = express.Router();

router.post("/save-csv", (req, res) => {
  const { items } = req.body;

  if (!items || !Array.isArray(items)) {
    return res.status(400).json({ error: "Invalid item list" });
  }

  const csv = items.join("\n");

  // Folder where CSV will be created
  const filePath = path.join(process.cwd(), "final_list.csv");

  fs.writeFileSync(filePath, csv);

  console.log("CSV SAVED:", filePath);

  res.json({ success: true, path: filePath });
});

export default router;