import UserModel  from "../models/userModel.js ";


export const getUserData = async (req, res) => {
    try{
        const {userId} = req.body;
        const user = await UserModel.findById(userId);

        if(!user){
            return res.status(404).json({success: false, message: "User not found"});
        }
        res.json({success: true,
             userDetails: {
                 name: user.name,
                 email: user.email
             }
            });

    } catch(error) {
        res.status(500).json({ success: false, message: error.message });
    }
}
