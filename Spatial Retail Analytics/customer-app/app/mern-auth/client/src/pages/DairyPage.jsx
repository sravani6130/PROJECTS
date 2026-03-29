import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const dairyItems = [
  "Milk",
  "Butter",
  "Cheese",
  "Bread",
  "Yogurt",
  "Cakes",
];

const DairyPage = () => {
  const [selectedDairy, setSelectedDairy] = useState(
    JSON.parse(localStorage.getItem("dairy_csv")) || []  // Load saved items
  );

  const navigate = useNavigate();

  const toggleItem = (item) => {
    setSelectedDairy((prev) =>
      prev.includes(item)
        ? prev.filter((i) => i !== item)
        : [...prev, item]
    );
  };

  // 🔥 Auto-save to localStorage
  useEffect(() => {
    localStorage.setItem("dairy_csv", JSON.stringify(selectedDairy));
  }, [selectedDairy]);

  const handleConfirm = () => {
    navigate("/aisles");
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Dairy & Bakery</h2>

        <div className="category-grid">
          {dairyItems.map((item) => (
            <div
              key={item}
              className={`category-card ${
                selectedDairy.includes(item) ? "selected" : ""
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

export default DairyPage;
