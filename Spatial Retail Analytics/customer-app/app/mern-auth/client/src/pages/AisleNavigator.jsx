import React, { useState, useEffect } from "react";
import "../styles/AisleNavigator.css";
import { useNavigate } from "react-router-dom";
import Header from "../components/Header";

const AisleNavigator = () => {
  const navigate = useNavigate();
  const [selectedCategories, setSelectedCategories] = useState([]);

  // 🟢 CLEAR LOCAL STORAGE IF BACKEND RESTARTED
  useEffect(() => {
    fetch("http://localhost:5000/restart-time")
      .then((res) => res.json())
      .then((data) => {
        const lastRestart = localStorage.getItem("backend_restart");

        if (lastRestart !== data.time) {
          console.log("🔄 Backend restarted → Clearing stored CSV lists");

          [
            "fruit_csv",
            "snacks_csv",
            "dairy_csv",
            "beverages_csv",
            "cleaning_csv",
            "frozen_csv",
          ].forEach((key) => localStorage.removeItem(key));

          localStorage.setItem("backend_restart", data.time);
        }
      })
      .catch((err) => console.error("Restart check failed:", err));
  }, []);

  const categories = [
    { id: 1, name: "Fruits & Vegetables", img: "/images/fruits.png" },
    { id: 2, name: "Snacks", img: "/images/Snacks.png" },
    { id: 3, name: "Dairy & Bakery", img: "/images/Dairy.png" },
    { id: 4, name: "Beverages", img: "/images/Beverages.png" },
    { id: 5, name: "Cleaning Supplies", img: "/images/Cleaning.png" },
    { id: 6, name: "Frozen Foods", img: "/images/Frozen.png" },
  ];

  const toggleSelect = (name) => {
    setSelectedCategories((prev) =>
      prev.includes(name)
        ? prev.filter((c) => c !== name)
        : [...prev, name]
    );
  };

  // ⭐ MERGE ALL SHOPPING CSV LISTS + GENERATE IMAGE
  const handleContinue = async () => {
    const storageKeys = [
      "fruit_csv",
      "snacks_csv",
      "dairy_csv",
      "beverages_csv",
      "cleaning_csv",
      "frozen_csv",
    ];

    let allItems = [];

    storageKeys.forEach((key) => {
      const items = JSON.parse(localStorage.getItem(key)) || [];
      allItems.push(...items);
    });

    allItems = [...new Set(allItems)].filter(Boolean);

    if (allItems.length === 0) {
      alert("❌ No items selected!");
      return;
    }

    console.log("➡ FINAL SHOPPING LIST:", allItems);

    try {
      // 🟢 Save CSV
      await fetch("http://localhost:5000/save-csv", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ items: allItems }),
      });

      console.log("📁 CSV Saved");

      // 🟢 Generate Visualization
      const res = await fetch(
        "http://localhost:5000/api/visual/generate-visual"
      );
      const data = await res.json();

      if (data.success) {
        console.log("🖼 IMAGE GENERATED:", data.image);

        // Save for viewing later
        localStorage.setItem(
          "shopping_image",
          `http://localhost:5000${data.image}`
        );

        alert("🟢 Visualization Ready! Redirecting...");
        navigate("/visual");
      } else {
        alert("❌ Failed to generate image");
      }
    } catch (err) {
      console.error(err);
      alert("❌ Error connecting to backend!");
    }
  };

  const handleCategoryClick = (categoryName) => {
    toggleSelect(categoryName);

    const routeMap = {
      "Fruits & Vegetables": "/fruits",
      Snacks: "/snacks",
      "Dairy & Bakery": "/dairy",
      Beverages: "/beverages",
      "Cleaning Supplies": "/cleaning",
      "Frozen Foods": "/frozen",
    };

    if (routeMap[categoryName]) {
      navigate(routeMap[categoryName]);
    }
  };

  return (
    <>
      <Header />

      <div className="aisle-container">
        <h2 className="aisle-title">Choose What You Want to Shop</h2>
        <p className="aisle-subtitle">
          Select categories to generate the shortest shopping route
        </p>

        <div className="category-grid">
          {categories.map((category) => (
            <div
              key={category.id}
              className={`category-card ${
                selectedCategories.includes(category.name) ? "selected" : ""
              }`}
              onClick={() => handleCategoryClick(category.name)}
            >
              <img src={category.img} alt={category.name} className="category-img" />
              <h3 className="category-name">{category.name}</h3>
            </div>
          ))}
        </div>

        <button className="continue-btn" onClick={handleContinue}>
          Continue
        </button>
      </div>
    </>
  );
};

export default AisleNavigator;
