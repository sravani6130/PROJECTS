import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const frozenItems = [
  "Ice Cream",
  "SeaFood",
  "Peas",
  "French Fries",
  "Chicken Nuggets",
];

const FrozenPage = () => {
  const [selectedFrozen, setSelectedFrozen] = useState(
    JSON.parse(localStorage.getItem("frozen_csv")) || []  // Load saved items
  );

  const navigate = useNavigate();

  const toggleItem = (item) => {
    setSelectedFrozen((prev) =>
      prev.includes(item)
        ? prev.filter((i) => i !== item)
        : [...prev, item]
    );
  };

  // 🔥 Auto-save to localStorage on every update
  useEffect(() => {
    localStorage.setItem("frozen_csv", JSON.stringify(selectedFrozen));
  }, [selectedFrozen]);

  const handleConfirm = () => {
    navigate("/aisles");   // Go back to aisle page
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Frozen Foods</h2>

        <div className="category-grid">
          {frozenItems.map((item) => (
            <div
              key={item}
              className={`category-card ${
                selectedFrozen.includes(item) ? "selected" : ""
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

export default FrozenPage;
