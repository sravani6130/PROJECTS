import React, { useState, useEffect } from "react";
import Header from "../components/Header";
import { useNavigate } from "react-router-dom";

const fruitList = [
  "Apples",
  "Bananas",
  "Grapes",
  "Oranges",
  "Pineapple",
  "Watermelon",
];

const FruitsPage = () => {
  const [selectedFruits, setSelectedFruits] = useState(
    JSON.parse(localStorage.getItem("fruit_csv")) || []   // Load saved CSV on refresh
  );

  const navigate = useNavigate();

  const toggleFruit = (fruit) => {
    setSelectedFruits((prev) =>
      prev.includes(fruit) ? prev.filter((f) => f !== fruit) : [...prev, fruit]
    );
  };

  // 🔥 Save CSV automatically whenever selection changes
  useEffect(() => {
    localStorage.setItem("fruit_csv", JSON.stringify(selectedFruits));
  }, [selectedFruits]);

  const handleConfirm = () => {
    navigate("/aisles");
  };

  return (
    <>
      <Header />
      <div className="aisle-container">
        <h2 className="aisle-title">Select Fruits</h2>

        <div className="category-grid">
          {fruitList.map((fruit) => (
            <div
              key={fruit}
              className={`category-card ${
                selectedFruits.includes(fruit) ? "selected" : ""
              }`}
              onClick={() => toggleFruit(fruit)}
            >
              <h3 className="category-name">{fruit}</h3>
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

export default FruitsPage;
