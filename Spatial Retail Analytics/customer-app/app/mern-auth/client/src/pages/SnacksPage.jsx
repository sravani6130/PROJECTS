import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const snacksItems = [
  "Chips",
  "Cookies",
  "Namkeen",
  "Popcorn",
  "Nuts",
];

const SnacksPage = () => {
  const [selectedSnacks, setSelectedSnacks] = useState(
    JSON.parse(localStorage.getItem("snacks_csv")) || []   // Load saved selections
  );

  const navigate = useNavigate();

  const toggleItem = (item) => {
    setSelectedSnacks((prev) =>
      prev.includes(item)
        ? prev.filter((i) => i !== item)
        : [...prev, item]
    );
  };

  // 🔥 Auto-save every change to localStorage
  useEffect(() => {
    localStorage.setItem("snacks_csv", JSON.stringify(selectedSnacks));
  }, [selectedSnacks]);

  const handleConfirm = () => {
    navigate("/aisles");   // Go back to aisle navigator
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Snacks</h2>

        <div className="category-grid">
          {snacksItems.map((item) => (
            <div
              key={item}
              className={`category-card ${
                selectedSnacks.includes(item) ? "selected" : ""
              }`}
              onClick={() => toggleItem(item)}
            >
              <h3 className="category-name">{item}</h3>
            </div>
          ))}
        </div>

        <button className="continue-btn active" onClick={handleConfirm}>
          Confirm Selection
        </button>
      </div>
    </>
  );
};

export default SnacksPage;
