import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import cookieParser from 'cookie-parser';
import connectDB from './config/mongodb.js'; // Ensure this file correctly connects to MongoDB
import authRouter from './routes/authRoutes.js';
import userRouter from './routes/userRoutes.js';
import uploadRouter from './routes/uploadRoutes.js';

// Load environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

// Connect to MongoDB
connectDB();

// Middleware
app.use(express.json()); 
app.use(cookieParser());

app.use(cors({
  origin: 'http://localhost:5173', // Allow frontend to access backend
  credentials: true, // Allow cookies
}));

// Test API Endpoint
app.get('/', (req, res) => {
  res.send('Hello pap, Server is running successfully!');
});

// Routes
app.use('/api/auth', authRouter);
app.use('/api/user', userRouter);
app.use('/api', uploadRouter);


// Start the server
app.listen(port, () => console.log(`🚀 Server is running on port ${port}`));
