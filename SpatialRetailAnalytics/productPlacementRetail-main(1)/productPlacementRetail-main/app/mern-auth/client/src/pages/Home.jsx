import React from 'react';
import Navbar from '../components/Navbar';
import Header from '../components/Header';
import { Link } from 'react-router-dom';
import backgroundImage from '../assets/supermarket1.jpg'; // ✅ Import image

import './Home.css';

const Home = () => {
  return (
    <div className="home-container">
      <Header />

      {/* Why This Website */}
      <div className="background">
        <div className="overlay-content">
          <h2 className="headline">Turn Shelf Space into Sales Power.</h2>

          <p className="intro-paragraph">
          Boost your supermarket revenue with AI-driven product placement.
          We turn your shelf space into sales power—smart, simple, and effective.
          </p>

          <Link to="/login">
            <button className="start-button">Start</button>
          </Link>
        </div>
      </div>
    </div>
  );
};

export default Home;