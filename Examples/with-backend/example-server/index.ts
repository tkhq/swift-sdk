import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import bodyParser from "body-parser";
import {
  sendOtp,
  verifyOtp,
  otp,
  createSubOrg,
  oAuth,
} from "./src/handler.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());

async function handleRequest<T>(
  req: Request,
  res: Response<T>,
  handler: (req: Request) => Promise<T>,
) {
  try {
    const result = await handler(req);
    res.json(result);
  } catch (error: any) {
    console.error("Server error:", error.message);
    res.status(500).json({ error: error.message } as any);
  }
}

app.post("/auth/createSubOrg", (req, res) =>
  handleRequest(req, res, createSubOrg),
);

app.post("/auth/sendOtp", (req, res) =>
  handleRequest(req, res, sendOtp),
);
app.post("/auth/verifyOtp", (req, res) => handleRequest(req, res, verifyOtp));
app.post("/auth/otp", (req, res) => handleRequest(req, res, otp));

app.post("/auth/oAuth", (req, res) => handleRequest(req, res, oAuth));

app.listen(PORT, () =>
  console.log(`✅ Server running on http://localhost:${PORT}`),
);
