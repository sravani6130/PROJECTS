import React, { useEffect } from "react";
import "../styles/Home.css";
import { Gift, Target, Smartphone, Bell } from "lucide-react";

const Home = () => {
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("animate-in");
          }
        });
      },
      { threshold: 0.1, rootMargin: "0px 0px -50px 0px" }
    );

    document.querySelectorAll(".feature-card, .step-card").forEach((el) => {
      observer.observe(el);
    });

    return () => observer.disconnect();
  }, []);

  return (
    <div className="home-container">
      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-content">
          <h1 className="hero-title">Smart Shopping Experience</h1>
          <p className="hero-subtitle">
            Earn rewards, discover personalized offers, and enjoy a seamless
            shopping journey powered by AI. Transform every visit into an
            engaging adventure with challenges, loyalty points, and exclusive
            deals.
          </p>
          <button
            className="cta-button"
            onClick={() =>
              document.getElementById("features")?.scrollIntoView({
                behavior: "smooth",
              })
            }
          >
            Explore Features
          </button>
        </div>
      </section>

      {/* Features Section */}
      <section className="features-section" id="features">
        <div className="section-header">
          <h2 className="section-title">Exciting Features</h2>
          <p className="section-description">
            Discover how our intelligent platform makes shopping more rewarding,
            personalized, and fun
          </p>
        </div>

        <div className="features-grid">
          <div className="feature-card">
            <div className="feature-icon-wrapper feature-icon-red">
              <Target size={40} color="#dc2626" strokeWidth={2} />
            </div>
            <h3>Zone Challenges & Loyalty Rewards</h3>
            <p>Complete fun shopping missions and earn exclusive rewards</p>
            <ul className="feature-benefits">
              <li>Earn points for visiting specific zones</li>
              <li>Unlock badges and achievements</li>
              <li>Track your progress in real-time</li>
              <li>Redeem rewards for discounts</li>
            </ul>
          </div>

          <div className="feature-card">
            <div className="feature-icon-wrapper feature-icon-blue">
              <Gift size={40} color="#2563eb" strokeWidth={2} />
            </div>
            <h3>Personalized Offer Zones</h3>
            <p>Get instant discounts on products you love</p>
            <ul className="feature-benefits">
              <li>AI-powered product recommendations</li>
              <li>Real-time personalized discounts</li>
              <li>Location-based special offers</li>
              <li>Smart alerts for your favorites</li>
            </ul>
          </div>

          <div className="feature-card">
            <div className="feature-icon-wrapper feature-icon-green">
              <Smartphone size={40} color="#16a34a" strokeWidth={2} />
            </div>
            <h3>Social Sharing Rewards</h3>
            <p>Share your finds and earn bonus points</p>
            <ul className="feature-benefits">
              <li>Share products on social media</li>
              <li>Earn points for each share</li>
              <li>Unlock exclusive discounts</li>
              <li>Build your shopping community</li>
            </ul>
          </div>

          <div className="feature-card">
            <div className="feature-icon-wrapper feature-icon-yellow">
              <Bell size={40} color="#ca8a04" strokeWidth={2} />
            </div>
            <h3>Smart Restocking Alerts</h3>
            <p>Never miss your favorite products</p>
            <ul className="feature-benefits">
              <li>Get notified when items restock</li>
              <li>AI predicts availability</li>
              <li>Plan your shopping better</li>
              <li>Always find what you need</li>
            </ul>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="how-it-works">
        <div className="section-header">
          <h2 className="section-title">How It Works</h2>
          <p className="section-description">
            Getting started is simple - just three easy steps to unlock amazing
            rewards
          </p>
        </div>

        <div className="steps-container">
          <div className="step-card">
            <div className="step-number">1</div>
            <h4>Download & Sign Up</h4>
            <p>
              Create your account and complete your profile to start earning
              points immediately
            </p>
          </div>

          <div className="step-card">
            <div className="step-number">2</div>
            <h4>Shop & Engage</h4>
            <p>
              Visit zones, complete challenges, and interact with products to
              earn rewards
            </p>
          </div>

          <div className="step-card">
            <div className="step-number">3</div>
            <h4>Redeem & Enjoy</h4>
            <p>
              Use your points for discounts, exclusive offers, and special perks
            </p>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="final-cta">
        <h2>Ready to Transform Your Shopping?</h2>
        <p>
          Join thousands of smart shoppers already enjoying rewards and
          personalized experiences
        </p>
        <button
          className="final-cta-button"
          onClick={() => alert("App download coming soon!")}
        >
          Download Now
        </button>
      </section>
    </div>
  );
};

export default Home;