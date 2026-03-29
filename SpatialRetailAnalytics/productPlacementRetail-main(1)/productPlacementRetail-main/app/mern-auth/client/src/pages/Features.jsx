import React, { useEffect } from "react";
import "./Features.css";
import Header from '../components/Header';
// Add icon imports (assumes react-icons is installed)
import { FaUserLock, FaUpload, FaChartLine, FaMagic, 
        FaDownload, FaTrash, FaMobile, FaBell } from "react-icons/fa";

const Features = () => {
  // Features organized by category
  const featureCategories = [
    {
      title: "Data Management",
      features: [
        {
          icon: <FaUpload />,
          title: "Upload Item Dataset",
          description: "Upload item metadata (ID, brand, category) in CSV format for optimized placement.",
        },
        {
          icon: <FaChartLine />,
          title: "Upload Transactional Dataset",
          description: "Upload historical sales data to power the placement algorithm.",
        },
        {
          icon: <FaDownload />,
          title: "View & Download Plans",
          description: "Easily review and download previously generated placement plans.",
        },
        {
          icon: <FaTrash />,
          title: "Delete Outdated Plans",
          description: "Clean up old runs that are no longer useful with a single click.",
        },
      ]
    },
    {
      title: "Core Functionality",
      features: [
        {
          icon: <FaUserLock />,
          title: "User Registration & Login",
          description: "Secure access for shop managers and retailers to manage placement operations.",
        },
        {
          icon: <FaMagic />,
          title: "Generate Placement Plan",
          description: "Automatically compute optimal placements for premium store slots using internal logic.",
        },
      ]
    },
    {
      title: "User Experience",
      features: [
        {
          icon: <FaMobile />,
          title: "Responsive Dashboard",
          description: "Access all functionalities on desktop, tablet, or mobile devices.",
        },
        {
          icon: <FaBell />,
          title: "Error Notifications",
          description: "Friendly alerts guide users during upload or process failures.",
        },
      ]
    }
  ];

  // Animation effect for staggered card appearance
  useEffect(() => {
    const featureCards = document.querySelectorAll('.feature-card');
    featureCards.forEach((card, index) => {
      setTimeout(() => {
        card.classList.add('feature-card-visible');
      }, 100 * index);
    });
  }, []);

  return (
    <>
      <Header />
      <div className="features-page">
        <div className="features-hero">
          <p className="features-subtitle">Discover how our platform streamlines your product placement strategy</p>
        </div>
        
        {featureCategories.map((category, categoryIndex) => (
          <div key={categoryIndex} className="feature-category">
            <h2 className="category-title">{category.title}</h2>
            <div className="features-grid">
              {category.features.map((feature, featureIndex) => (
                <div key={featureIndex} className="feature-card">
                  <div className="feature-icon">{feature.icon}</div>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </>
  );
};

export default Features;
