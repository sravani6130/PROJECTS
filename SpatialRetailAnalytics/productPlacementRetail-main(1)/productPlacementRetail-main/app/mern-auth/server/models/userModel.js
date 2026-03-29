import mongoose from "mongoose";
import jwt from "jsonwebtoken";

const userSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    password: {
        type: String,
        required: true
    },
    status: { 
        type: String, 
        default: "inactive"
    } // Store JWT token for session tracking
});

const UserModel = mongoose.models.User || mongoose.model('User', userSchema);

export default UserModel;
