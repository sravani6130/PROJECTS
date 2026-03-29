import jwt from "jsonwebtoken";

const userAuth = async (req, res, next) => {
    const token = req.cookies?.token || req.header("Authorization")?.split(" ")[1]; // ✅ Extract token correctly

    if (!token) {
        return res.json({ success: false, message: "Not Authorized. Try logging in again" });
    }

    try {
        const tokenDecode = jwt.verify(token, process.env.JWT_SECRET);
        
        if (tokenDecode?.id) {
            req.body.userId = tokenDecode.id;
            next();
        } else {
            return res.json({ success: false, message: "Not Authorized. Try logging in again" });
        }
    } catch (error) {
        res.json({ success: false, message: error.message });
    }
};

export default userAuth;
