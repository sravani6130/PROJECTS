import React, { useState, useEffect } from "react";
import "../styles/AisleNavigator.css";
import { useNavigate } from "react-router-dom";
import Header from "../components/Header";
export default function VisualPage() {
  const img = localStorage.getItem("shopping_image");

  return (
    <div style={{ textAlign: "center", padding: "20px" }}>
     <h1 style={{ marginTop:"100px",marginBottom: "30px" }}>🛒 Optimized Shopping Route</h1>

      {img ? (
        <img
          src={img}
          alt="Shopping Path"
          style={{
            width: "90%",
            maxWidth: "1200px",
            borderRadius: "16px",
            boxShadow: "0px 0px 25px rgba(0,0,0,0.3)",
          
          }}
        />
      ) : (
        <h2>⚠ No image found!</h2>
      )}
    </div>
  );
}
