import React, { useState } from 'react';
import '../styles/Login.css';
import { useNavigate } from 'react-router-dom';
import Header from '../components/Header';
import { FaEye, FaEyeSlash } from 'react-icons/fa'; // Formal icons
import { Link } from 'react-router-dom'; // For internal routing

const LoginPage = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [rememberMe, setRememberMe] = useState(false);
  const navigate = useNavigate();


  const handleLogin = (e) => {
    e.preventDefault();

    // Simple validation
    if (!email || !password) {
      setError('Please fill in all fields');
      return;
    }

    if (!email.includes('@')) {
      setError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    // Clear previous errors
    setError('');

    // Placeholder login logic
    console.log('Login attempt:', { email, password, rememberMe });
    navigate('/dashboard');
  };

  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  return (
    <>
      <Header />
      <div className="login-container">
        <div className="login-box">
          <div className="decorative-dots">
            <div className="dot dot-1"></div>
            <div className="dot dot-2"></div>
            <div className="dot dot-3"></div>
          </div>

          <div className="login-header">
            <h2>Welcome Back</h2>
            <p className="login-subtitle">Sign in to continue your journey</p>
          </div>

          <form onSubmit={handleLogin}>
            <div className="error-container">
              {error && <div className="error-message show">{error}</div>}
            </div>

            <div className="textbox">
              <label htmlFor="email">Email</label>
              <input
                type="text"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Your email address"
              />
            </div>

            <div className="textbox password-container">
              <label htmlFor="password">Password</label>
              <div className="password-input-wrapper">
                <input
                  type={showPassword ? 'text' : 'password'}
                  id="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Your password"
                />
                <span className="eye-icon" onClick={togglePasswordVisibility}>
                  {showPassword ? <FaEyeSlash /> : <FaEye />}
                </span>
              </div>
            </div>

            <div className="options">
              <div className="remember-me">
                <input
                  type="checkbox"
                  id="remember"
                  checked={rememberMe}
                  onChange={() => setRememberMe(!rememberMe)}
                />
                <label htmlFor="remember">Remember me</label>
              </div>
              <a href="#forgot-password" className="forgot-link">
                Forgot password?
              </a>
            </div>

            <button type="submit" className="btn">
              Sign In
            </button>
          </form>

          <div className="signup">
            Don't have an account?{' '}
            <Link to="/register" className="signup-link">
              Create account
            </Link>
          </div>
        </div>
      </div>
    </>
  );
};

export default LoginPage;
