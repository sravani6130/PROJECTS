import express from 'express';
import { login, register, logout, isAuthenticated } from '../controllers/authController.js';
import userAuth from '../middleware/userAuth.js';

const authRouter = express.Router();

authRouter.post('/register', register);
authRouter.post('/login', login);
authRouter.post('/logout', logout);
authRouter.get('/is-auth', userAuth, isAuthenticated);

// Protected Dashboard Route
authRouter.get('/dashboard', userAuth, (req, res) => {
    res.status(200).json({ message: 'Welcome to the Dashboard!', user: req.user });
});

export default authRouter;
