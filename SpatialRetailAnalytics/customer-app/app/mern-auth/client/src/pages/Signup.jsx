import React from "react";
import "../styles/signup.css";

const Signup = () => (
  <div className="signup-page">
    <h2>Signup</h2>
    <form>
      <input type="text" placeholder="Name" />
      <input type="text" placeholder="Email" />
      <input type="password" placeholder="Password" />
      <button type="submit">Register</button>
    </form>
  </div>
);

export default Signup;
