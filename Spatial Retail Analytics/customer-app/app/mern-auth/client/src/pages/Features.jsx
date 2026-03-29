import React from "react";
import "../styles/features.css";

const features = [
  {
    icon: "🎯",
    title: "Zone Challenges & Loyalty Rewards",
    desc: "Complete fun shopping missions and earn exclusive rewards",
    benefits: [
      "Earn points for visiting specific zones",
      "Unlock badges and achievements",
      "Track your progress in real-time",
      "Redeem rewards for discounts",
    ],
  },
  {
    icon: "🎁",
    title: "Personalized Offer Zones",
    desc: "Get instant discounts on products you love",
    benefits: [
      "AI-powered product recommendations",
      "Real-time personalized discounts",
      "Location-based special offers",
      "Smart alerts for your favorites",
    ],
  },
  {
    icon: "📱",
    title: "Social Sharing Rewards",
    desc: "Share your finds and earn bonus points",
    benefits: [
      "Share products on social media",
      "Earn points for each share",
      "Unlock exclusive discounts",
      "Build your shopping community",
    ],
  },
  {
    icon: "✨",
    title: "Smart Restocking Alerts",
    desc: "Never miss your favorite products",
    benefits: [
      "Get notified when items restock",
      "AI predicts availability",
      "Plan your shopping better",
      "Always find what you need",
    ],
  },
];

const Features = () => (
  <section className="features-section" id="features">
    <div className="section-header">
      <h2 className="section-title">Exciting Features</h2>
      <p className="section-description">
        Discover how our intelligent platform makes shopping more rewarding, personalized, and fun
      </p>
    </div>

    <div className="features-grid">
      {features.map((f, i) => (
        <div className="feature-card" key={i}>
          <div className="feature-icon">{f.icon}</div>
          <h3>{f.title}</h3>
          <p>{f.desc}</p>
          <ul className="feature-benefits">
            {f.benefits.map((b, j) => <li key={j}>{b}</li>)}
          </ul>
        </div>
      ))}
    </div>
  </section>
);

export default Features;
