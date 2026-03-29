import React from 'react';
import './Pricing.css';
import Header from '../components/Header';
import { Link } from 'react-router-dom';
import { FaCheckCircle, FaHeadset, FaUsers, FaChartLine, FaTools } from 'react-icons/fa';

const Pricing = () => {
  return (
    <div className="pricing-container">
      <Header />
      
      <div className="pricing-hero">
        <div className="hero-content">
          <h1 className="pricing-title">Pricing Plans for Every Retail Business</h1>
          <p className="pricing-subtitle">Choose the solution that fits your business size and optimization needs</p>
        </div>
        <div className="decorative-shape"></div>
      </div>

      <div className="pricing-cards">
        {/* Basic Plan */}
        <div className="pricing-card">
          <div className="card-header">
            <h2>Basic</h2>
            <p className="price">$299<span>/month</span></p>
            <p className="billing-cycle">Billed annually or $349 monthly</p>
          </div>
          <div className="card-body">
            <p className="card-description">Perfect for small retailers starting with data-driven shelf optimization</p>
            <ul className="features-list">
              <li><FaCheckCircle className="icon" /> <span>Up to 5,000 sq ft of retail space</span></li>
              <li><FaCheckCircle className="icon" /> <span>Basic planogram generation</span></li>
              <li><FaCheckCircle className="icon" /> <span>Weekly optimization suggestions</span></li>
              <li><FaCheckCircle className="icon" /> <span>2 user accounts</span></li>
              <li><FaCheckCircle className="icon" /> <span>Email support</span></li>
            </ul>
          </div>
          <div className="card-footer">
            <Link to="/login" className="button-link">
              <button className="pricing-btn">Start 14-Day Trial</button>
            </Link>
            <p className="no-card-required">No credit card required</p>
          </div>
        </div>

        {/* Professional Plan */}
        <div className="pricing-card popular">
          <div className="popular-tag">
             Most Popular
          </div>
          <div className="card-header">
            <h2>Professional</h2>
            <p className="price">$599<span>/month</span></p>
            <p className="billing-cycle">Billed annually or $699 monthly</p>
          </div>
          <div className="card-body">
            <p className="card-description">Advanced features for growing retailers with multiple departments</p>
            <ul className="features-list">
              <li><FaCheckCircle className="icon" /> <span>Up to 20,000 sq ft of retail space</span></li>
              <li><FaCheckCircle className="icon" /> <span>Advanced AI planogram generation</span></li>
              <li><FaCheckCircle className="icon" /> <span>Daily optimization suggestions</span></li>
              <li><FaCheckCircle className="icon" /> <span>Cross-selling analytics dashboard</span></li>
              <li><FaCheckCircle className="icon" /> <span>Seasonal trend forecasting</span></li>
              <li><FaCheckCircle className="icon" /> <span>10 user accounts</span></li>
              <li><FaCheckCircle className="icon" /> <span>Priority support</span></li>
            </ul>
          </div>
          <div className="card-footer">
            <Link to="/login" className="button-link">
              <button className="pricing-btn highlight-btn">Start 14-Day Trial</button>
            </Link>
            <p className="no-card-required">No credit card required</p>
          </div>
        </div>

        {/* Enterprise Plan */}
        <div className="pricing-card">
          <div className="card-header">
            <h2>Enterprise</h2>
            <p className="price">Custom</p>
            <p className="billing-cycle">Tailored to your business needs</p>
          </div>
          <div className="card-body">
            <p className="card-description">Complete solution for large retail chains and supermarkets</p>
            <ul className="features-list">
              <li><FaCheckCircle className="icon" /> <span>Unlimited retail space</span></li>
              <li><FaCheckCircle className="icon" /> <span>Custom AI model training</span></li>
              <li><FaCheckCircle className="icon" /> <span>Real-time optimization</span></li>
              <li><FaCheckCircle className="icon" /> <span>Multi-store management</span></li>
              <li><FaCheckCircle className="icon" /> <span>Inventory integration</span></li>
              <li><FaCheckCircle className="icon" /> <span>Unlimited user accounts</span></li>
              <li><FaCheckCircle className="icon" /> <span>Dedicated account manager</span></li>
              <li><FaCheckCircle className="icon" /> <span>24/7 priority support</span></li>
            </ul>
          </div>
          <div className="card-footer">
            <Link to="/contact" className="button-link">
              <button className="pricing-btn">Contact Sales</button>
            </Link>
            <p className="enterprise-contact">Get a customized quote</p>
          </div>
        </div>
      </div>

      <div className="benefits-section">
        <h2>Why Choose Shelf Optimizer?</h2>
        <div className="benefits-grid">
          <div className="benefit-item">
            <div className="benefit-icon">
              <FaChartLine />
            </div>
            <h3>Increase Sales</h3>
            <p>Boost your revenue by up to 23% with AI-optimized product placement</p>
          </div>
          <div className="benefit-item">
            <div className="benefit-icon">
              <FaTools />
            </div>
            <h3>Easy Implementation</h3>
            <p>Get up and running quickly with our intuitive interface and implementation team</p>
          </div>
          <div className="benefit-item">
            <div className="benefit-icon">
              <FaUsers />
            </div>
            <h3>Customer Satisfaction</h3>
            <p>Improve the shopping experience with logical, customer-centric layouts</p>
          </div>
          <div className="benefit-item">
            <div className="benefit-icon">
              <FaHeadset />
            </div>
            <h3>Dedicated Support</h3>
            <p>Our retail optimization experts are available to help you succeed</p>
          </div>
        </div>
      </div>

      <div className="faq-section">
        <h2>Frequently Asked Questions</h2>
        <div className="faq-grid">
          <div className="faq-item">
            <h3>How quickly can I see results?</h3>
            <p>Most retailers see measurable sales increases within the first 30 days after implementing our shelf optimization recommendations.</p>
          </div>
          <div className="faq-item">
            <h3>Can I upgrade my plan later?</h3>
            <p>Yes! You can upgrade your plan at any time. Your billing will be prorated for the remainder of your billing cycle.</p>
          </div>
          <div className="faq-item">
            <h3>Do you offer refunds?</h3>
            <p>We offer a 30-day money-back guarantee if you're not completely satisfied with our service.</p>
          </div>
          <div className="faq-item">
            <h3>How difficult is implementation?</h3>
            <p>Our team provides comprehensive onboarding support to ensure a smooth transition. Most clients are fully operational within 1-2 weeks.</p>
          </div>
        </div>
      </div>

      <div className="pricing-cta">
        <div className="cta-content">
          <h2>Not sure which plan is right for you?</h2>
          <p>Our product specialists can help you find the perfect solution for your retail business.</p>
          <Link to="/demo" className="button-link">
            <button className="cta-btn">Schedule a Demo</button>
          </Link>
        </div>
        <div className="cta-decoration"></div>
      </div>
    </div>
  );
};

export default Pricing;