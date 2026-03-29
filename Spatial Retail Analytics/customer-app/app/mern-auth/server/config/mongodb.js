import mongoose from "mongoose";

const connectDB = async () => {
  try {
    mongoose.connection.on("connected", () => console.log("✅ MongoDB connected"));
    console.log("Connecting to:", process.env.MONGO_URI);
    await mongoose.connect(process.env.MONGO_URI);
  } catch (err) {
    console.error("❌ MongoDB connection error:", err.message);
  }
};

export default connectDB;
