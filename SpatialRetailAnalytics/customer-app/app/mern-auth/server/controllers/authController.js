import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import transporter from '../config/nodeMailer.js';
import UserModel from '../models/userModel.js';

export const register = async (req, res) => {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
        return res.status(400).json({ success: false, message: 'Please fill all fields' });
    }

    try {
        const existingUser = await UserModel.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ success: false, message: 'User already exists' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const user = await UserModel.create({
            name,
            email,
            password: hashedPassword
        });

        await user.save();

        return res.json({ success: true, message: 'Registration successful' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const login = async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ success: false, message: "Email and password are required" });
    }

    try {
        const user = await UserModel.findOne({ email });
        if (!user) {
            return res.status(400).json({ success: false, message: "Invalid email" });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ success: false, message: "Invalid password" });
        }

        const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "10d" });

        // Set status to active
        user.status = "active";
        await user.save();

        res.cookie("token", token, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: process.env.NODE_ENV === "production" ? "none" : "strict",
            maxAge: 10 * 24 * 60 * 60 * 1000 // 10 days
        });

        return res.json({ success: true, message: "Login successful", user });

    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};
export const logout = async (req, res) => {
    try {
        let token = req.cookies?.token || req.header("Authorization")?.split(" ")[1];
        if (!token) {
            return res.status(401).json({ success: false, message: "Not authenticated" });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await UserModel.findById(decoded.id);

        if (!user) {
            return res.status(401).json({ success: false, message: "User not found" });
        }

        // Set status to inactive
        user.status = "inactive";
        await user.save();

        res.clearCookie("token", {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: process.env.NODE_ENV === "production" ? "none" : "strict",
        });

        return res.json({ success: true, message: "Logged out successfully" });

    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const isAuthenticated = async (req, res) => {
    try {
        let token = req.cookies?.token || req.header("Authorization")?.split(" ")[1];

        if (!token || typeof token !== "string") {
            return res.status(401).json({ success: false, message: "Not authenticated, token missing or invalid" });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await UserModel.findById(decoded.id).select("-password");

        if (!user || user.status !== "active") {
            return res.status(401).json({ success: false, message: "User not logged in" });
        }

        return res.json({ success: true, message: "User is authenticated", user });

    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};
