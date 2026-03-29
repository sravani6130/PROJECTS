import React, { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { assets } from "../assets/assets";
import { Menu } from "lucide-react";
import "./Header.css";

const Header = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const response = await fetch("http://localhost:4000/api/auth/is-auth", {
          method: "GET",
          credentials: "include", // Ensures cookies are sent
        });
        const data = await response.json();
        setIsAuthenticated(data.success);
      } catch (error) {
        setIsAuthenticated(false);
      }
    };

    checkAuth();
  }, []);

  const handleHomeClick = (e) => {
    e.preventDefault(); // Prevent default navigation
    navigate(isAuthenticated ? "/dashboard" : "/");
  };

  const handleLogout = async (e) => {
    e.preventDefault();
    try {
      await fetch("http://localhost:4000/api/auth/logout", {
        method: "POST",
        credentials: "include",
      });
      setIsAuthenticated(false);
      navigate("/");
    } catch (error) {
      console.error("Logout failed:", error);
    }
  };

  return (
    <header className="header">
      <div className="header-container">
        <Link to="/" className="logo-container">
          <img src={assets.header_img} alt="Logo" className="logo" />
        </Link>
        
        <h1 className="site-name">Shelf Optimizer</h1>
        
        {/* Navigation for larger screens */}
        <nav className="nav-links">
          <Link 
            to="/" 
            onClick={handleHomeClick} 
            className={location.pathname === '/' || 
                      (isAuthenticated && location.pathname === '/dashboard') ? 
                      'active' : ''}
          >
            Home
          </Link>
          <Link 
            to="/features" 
            className={location.pathname === '/features' ? 'active' : ''}
          >
            Features
          </Link>
          <Link 
            to="/heatmap" 
            className={location.pathname === '/heatmap' ? 'active' : ''}
          >
            Heatmap
          </Link>
          <Link 
            to="/pricing" 
            className={location.pathname === '/pricing' ? 'active' : ''}
          >
            Pricing
          </Link>
          {isAuthenticated ? (
            <a 
              href="/logout" 
              onClick={handleLogout}
              className={location.pathname === '/logout' ? 'active' : ''}
            >
              Logout
            </a>
          ) : (
            <Link 
              to="/login" 
              className={location.pathname === '/login' ? 'active' : ''}
            >
              Login
            </Link>
          )}
        </nav>

        {/* Mobile Menu Button */}
        <button className="menu-button" onClick={() => setIsMenuOpen(!isMenuOpen)}>
          <Menu className="menu-icon" />
        </button>
        
        {/* Decorative element */}
        <div className="decorative-element"></div>
      </div>

      {/* Mobile Navigation */}
      {isMenuOpen && (
        <div className="mobile-nav">
          <Link 
            to="/" 
            onClick={(e) => { 
              handleHomeClick(e); 
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
            <a 
              href="/logout" 
              onClick={(e) => {
                handleLogout(e);
                setIsMenuOpen(false);
              }}
            >
              Logout
            </a>
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