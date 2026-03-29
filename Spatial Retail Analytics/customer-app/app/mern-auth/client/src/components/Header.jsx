import React, { useState, useEffect } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import { assets } from "../assets/assets";
import { Menu } from "lucide-react";
import "../styles/Header.css";

const Header = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const response = await fetch("http://localhost:5000/api/auth/is-auth", {
          method: "GET",
          credentials: "include", // send cookies
        });
        const data = await response.json();
        setIsAuthenticated(data.success);
      } catch {
        setIsAuthenticated(false);
      }
    };
    checkAuth();
  }, []);

  const handleHomeClick = () => {
    navigate(isAuthenticated ? "/dashboard" : "/");
  };

  const handleLogout = async () => {
    try {
      await fetch("http://localhost:5000/api/auth/logout", {
        method: "POST",
        credentials: "include",
      });
      localStorage.removeItem("user");
      setIsAuthenticated(false);
      navigate("/");
    } catch (error) {
      console.error("Logout failed:", error);
    }
  };

  return (
    <header className="header">
      <div className="header-container">
        {/* Logo */}
        <div onClick={handleHomeClick} className="logo-container" style={{ cursor: "pointer" }}>
          <img src={assets.header_img} alt="Logo" className="logo" />
        </div>

        <h1 className="site-name">SmartCart</h1>

        {/* Desktop Navigation */}
        <nav className="nav-links">
          <Link
            to="/"
            onClick={handleHomeClick}
            className={
              location.pathname === "/" ||
              (isAuthenticated && location.pathname === "/dashboard")
                ? "active"
                : ""
            }
          >
            Home
          </Link>
         
           <Link
            to="/aislenavigator"
            className={location.pathname === "/aislenavigator" ? "active" : ""}
          >
            Aisle Navigator
          </Link>
          {isAuthenticated ? (
            <button
              onClick={handleLogout}
              className={location.pathname === "/logout" ? "active" : ""}
            >
              Logout
            </button>
          ) : (
            <Link
              to="/login"
              className={location.pathname === "/login" ? "active" : ""}
            >
              Login
            </Link>
          )}
        </nav>

        {/* Mobile Menu Toggle */}
        <button
          className="menu-button"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          <Menu className="menu-icon" />
        </button>

        {/* Decorative Element */}
        <div className="decorative-element"></div>
      </div>

      {/* Mobile Navigation */}
      {isMenuOpen && (
        <div className="mobile-nav">
          <Link
            to="/"
            onClick={() => {
              handleHomeClick();
              setIsMenuOpen(false);
            }}
          >
            Home
          </Link>
          <Link
            to="/features"
            onClick={() => setIsMenuOpen(false)}
          >
            Features
          </Link>
          <Link
            to="/pricing"
            onClick={() => setIsMenuOpen(false)}
          >
            Pricing
          </Link>
          {isAuthenticated ? (
            <button
              onClick={() => {
                handleLogout();
                setIsMenuOpen(false);
              }}
            >
              Logout
            </button>
          ) : (
            <Link
              to="/login"
              onClick={() => setIsMenuOpen(false)}
            >
              Login
            </Link>
          )}
        </div>
      )}
    </header>
  );
};

export default Header;
