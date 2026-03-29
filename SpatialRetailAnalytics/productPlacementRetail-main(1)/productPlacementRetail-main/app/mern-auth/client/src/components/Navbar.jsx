import React from "react";
import { useNavigate } from "react-router-dom";
import "./Navbar.css"; // Import the CSS file

const Navbar = () => {
  const navigate = useNavigate();

  return (
    <nav className="navbar">
      <div className="navbar-container">
        {/* Login Button Centered */}
        <button 
          onClick={() => navigate("/login")}  
          className="login-button"
        >
          Login
        </button>
      </div>
    </nav>
  );
};

export default Navbar;