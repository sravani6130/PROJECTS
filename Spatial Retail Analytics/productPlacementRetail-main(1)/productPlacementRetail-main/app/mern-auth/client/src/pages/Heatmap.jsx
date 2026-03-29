import React, { useState, useRef } from "react";
import Header from "../components/Header";
import {
  FiUpload,
  FiFile,
  FiX,
  FiCheckCircle,
  FiAlertTriangle,
} from "react-icons/fi";
import "./Heatmap.css";

const Heatmap = () => {
  // File states
  const [transactionsFile, setTransactionsFile] = useState(null);
  const [arrangementFile, setArrangementFile] = useState(null);
  const [layoutFile, setLayoutFile] = useState(null);

  // Returned image
  const [generatedImage, setGeneratedImage] = useState(null);

  const [isUploading, setIsUploading] = useState(false);
  const [message, setMessage] = useState("");

  // File input refs
  const transactionsRef = useRef(null);
  const arrangementRef = useRef(null);
  const layoutRef = useRef(null);

  // Handle input
  const handleFileChange = (e, setter) => {
    const file = e.target.files[0];
    if (!file) return;
    setter(file);
    setMessage("");
  };

  // Send to backend
  const handleProceed = async () => {
    if (!transactionsFile || !arrangementFile || !layoutFile) {
      setMessage("Please upload all files!");
      return;
    }

    setIsUploading(true);
    setMessage("");

    const formData = new FormData();
    formData.append("transactions", transactionsFile);
    formData.append("arrangement", arrangementFile);
    formData.append("layout", layoutFile);

    try {
      const response = await fetch("http://localhost:4000/api/generate-heatmap", {
        method: "POST",
        body: formData,
      });

      const data = await response.json();

      setIsUploading(false);

      if (data.image) {
        // Expecting { image: "data:image/png;base64,..." }
        setGeneratedImage(data.image);
        setMessage("Image generated successfully!");
      } else {
        setMessage("Processing failed.");
      }
    } catch (err) {
      console.error(err);
      setMessage("Error connecting to backend.");
      setIsUploading(false);
    }
  };

  return (
    <div className="dashboard-page">
      <Header />

      <div className="dashboard-content">
        <div className="dashboard-grid">
          {/* LEFT SIDE – File upload */}
          <div className="upload-card">
            <h2>Upload Required Files</h2>

            {/* TRANSACTIONS CSV */}
            <div
              className="file-upload-zone"
              onClick={() => transactionsRef.current.click()}
            >
              <input
                type="file"
                ref={transactionsRef}
                accept=".csv"
                hidden
                onChange={(e) => handleFileChange(e, setTransactionsFile)}
              />

              {transactionsFile ? (
                <div className="selected-file-info">
                  <FiFile />
                  <span>{transactionsFile.name}</span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setTransactionsFile(null);
                    }}
                  >
                    <FiX />
                  </button>
                </div>
              ) : (
                <div className="upload-placeholder">
                  <FiUpload />
                  <p>Upload Transactions CSV</p>
                </div>
              )}
            </div>

            {/* ARRANGEMENT CSV */}
            <div
              className="file-upload-zone"
              onClick={() => arrangementRef.current.click()}
            >
              <input
                type="file"
                ref={arrangementRef}
                accept=".csv"
                hidden
                onChange={(e) => handleFileChange(e, setArrangementFile)}
              />

              {arrangementFile ? (
                <div className="selected-file-info">
                  <FiFile />
                  <span>{arrangementFile.name}</span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setArrangementFile(null);
                    }}
                  >
                    <FiX />
                  </button>
                </div>
              ) : (
                <div className="upload-placeholder">
                  <FiUpload />
                  <p>Upload Arrangement CSV</p>
                </div>
              )}
            </div>

            {/* STORE LAYOUT IMAGE */}
            <div
              className="file-upload-zone"
              onClick={() => layoutRef.current.click()}
            >
              <input
                type="file"
                ref={layoutRef}
                accept="image/*"
                hidden
                onChange={(e) => handleFileChange(e, setLayoutFile)}
              />

              {layoutFile ? (
                <div className="selected-file-info">
                  <FiFile />
                  <span>{layoutFile.name}</span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setLayoutFile(null);
                    }}
                  >
                    <FiX />
                  </button>
                </div>
              ) : (
                <div className="upload-placeholder">
                  <FiUpload />
                  <p>Upload Layout Image (PNG/JPG)</p>
                </div>
              )}
            </div>

            {/* PROCEED BUTTON */}
            <button
              className="upload-btn"
              onClick={handleProceed}
              disabled={isUploading}
            >
              {isUploading ? "Processing..." : "Proceed"}
            </button>

            {/* MESSAGE */}
            {message && (
              <div
                className={`message ${
                  message.includes("success") ? "success" : "error"
                }`}
              >
                {message.includes("success") ? <FiCheckCircle /> : <FiAlertTriangle />}
                {message}
              </div>
            )}
          </div>

          {/* RIGHT SIDE – Preview heatmap */}
          <div className="results-card">
            <h2>Generated Heatmap</h2>

            {generatedImage ? (
           <div
  style={{
    paddingLeft: "100px",   // adjust as needed
    display: "flex",
    justifyContent: "flex-start",
  }}
>
  <img
    src={generatedImage}
    alt="Generated Heatmap"
    style={{
      width: "80%",
      height: "auto",
      objectFit: "contain",
    }}
  />
</div>
            ) : (
              <div className="empty-state">
                <p>No image yet. Upload files and click Proceed.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Heatmap;
