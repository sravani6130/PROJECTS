import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const beverageList = [
  "Tea",
  "Coffee",
  "Juice",
  "Soda",
  "Energy Drink",
  "Milkshake"
];

const BeveragesPage = () => {
  const [selectedBeverages, setSelectedBeverages] = useState(
    JSON.parse(localStorage.getItem("beverages_csv")) || []  // Load saved items
  );

  const navigate = useNavigate();

  const toggleBeverage = (item) => {
    setSelectedBeverages((prev) =>
      prev.includes(item) ? prev.filter((b) => b !== item) : [...prev, item]
    );
  };

  // 🔥 Auto-save to CSV storage
  useEffect(() => {
    localStorage.setItem("beverages_csv", JSON.stringify(selectedBeverages));
  }, [selectedBeverages]);

  const handleConfirm = () => {
    navigate("/aisles");
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Beverages</h2>

        <div className="category-grid">
          {beverageList.map((item) => (
            <div
              key={item}
              className={`category-card ${
                selectedBeverages.includes(item) ? "selected" : ""
              }`}
              onClick={() => toggleBeverage(item)}
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

export default BeveragesPage;
