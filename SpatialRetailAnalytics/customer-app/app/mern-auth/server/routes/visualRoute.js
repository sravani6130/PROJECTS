import express from "express";
import { exec } from "child_process";

const router = express.Router();

router.get("/generate-visual", (req, res) => {
  exec("python3 supermarket.py", (err, stdout, stderr) => {
    if (err) return res.status(500).json({ error: stderr });

    if (stdout.includes("IMAGE_SAVED")) {
      return res.json({ success: true, image: "/shopping_path.png" });
    }

    res.status(500).json({ error: "Image not generated" });
  });
});

export default router;