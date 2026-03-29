import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const cleaningList = [
  "Detergent",
  "Soap",
  "Sponges",
  "Bleach",
  "Floor Cleaner",
  "Toilet Cleaner"
];

const CleaningPage = () => {
  const [selectedCleanItems, setSelectedCleanItems] = useState(
    JSON.parse(localStorage.getItem("cleaning_csv")) || []   // Load saved CSV
  );

  const navigate = useNavigate();

  const toggleItem = (item) => {
    setSelectedCleanItems((prev) =>
      prev.includes(item) ? prev.filter((i) => i !== item) : [...prev, item]
    );
  };

  // 🔥 Save CSV automatically whenever selection changes
  useEffect(() => {
    localStorage.setItem("cleaning_csv", JSON.stringify(selectedCleanItems));
  }, [selectedCleanItems]);

  const handleConfirm = () => {
    navigate("/aisles");
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Cleaning Supplies</h2>

        <div className="category-grid">
          {cleaningList.map((item) => (
            <div
              key={item}
              className={`category-card ${
                selectedCleanItems.includes(item) ? "selected" : ""
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

export default CleaningPage;
