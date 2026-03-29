import React from "react";
import "../styles/howItWorks.css";

const steps = [
  {
    num: 1,
    title: "Download & Sign Up",
    desc: "Create your account and complete your profile to start earning points immediately",
  },
  {
    num: 2,
    title: "Shop & Engage",
    desc: "Visit zones, complete challenges, and interact with products to earn rewards",
  },
  {
    num: 3,
    title: "Redeem & Enjoy",
    desc: "Use your points for discounts, exclusive offers, and special perks",
  },
];

const HowItWorks = () => (
  <section className="how-it-works">
    <div className="section-header">
      <h2 className="section-title">How It Works</h2>
      <p className="section-description">
        Getting started is simple — just three easy steps to unlock amazing rewards
      </p>
    </div>
    <div className="steps-container">
      {steps.map((s, i) => (
        <div className="step-card" key={i}>
          <div className="step-number">{s.num}</div>
          <h4>{s.title}</h4>
          <p>{s.desc}</p>
        </div>
      ))}
    </div>
  </section>
);

export default HowItWorks;
