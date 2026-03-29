import React from "react";
import "../styles/cta.css";

const CTA = () => (
  <section className="final-cta">
    <h2>Ready to Transform Your Shopping?</h2>
    <p>Join thousands of smart shoppers already enjoying rewards and personalized experiences</p>
    <button
      className="final-cta-button"
      onClick={() => alert("App download coming soon!")}
    >
      Download Now
    </button>
  </section>
);

export default CTA;
