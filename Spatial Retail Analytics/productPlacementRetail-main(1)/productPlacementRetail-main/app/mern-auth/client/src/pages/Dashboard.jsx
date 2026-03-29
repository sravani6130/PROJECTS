import React, { useState, useRef, useEffect } from 'react';
import Header from '../components/Header';
import { 
  FiUpload, FiFile, FiCheckCircle, FiAlertTriangle, FiX, 
  FiBarChart2, FiGrid, FiDownload, FiDollarSign, FiBox, 
  FiShoppingCart, FiLayers, FiSliders 
} from 'react-icons/fi';
import './Dashboard.css';

const Dashboard = () => {
  const [itemsFile, setItemsFile] = useState(null);
  const [transactionsFile, setTransactionsFile] = useState(null);
  const [premiumSlots, setPremiumSlots] = useState(10); // Default value of 10
  const [message, setMessage] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const [results, setResults] = useState(null);
  const [isDragging, setIsDragging] = useState({ items: false, transactions: false });
  const [visualMode, setVisualMode] = useState('grid'); // 'grid', 'chart'
  const [processedData, setProcessedData] = useState([]);
  const [showAdvancedSettings, setShowAdvancedSettings] = useState(false);
  const [summaryData, setSummaryData] = useState(null);

  const itemsInputRef = useRef(null);
  const transactionsInputRef = useRef(null);

  // Process result data when results change
  useEffect(() => {
    if (results) {
      // Parse the text-based results
      parseResults(results);
    }
  }, [results]);

  // Parse the text output into structured data
  const parseResults = (resultsText) => {
    try {
      const lines = resultsText.split('\n');
      const processedItems = [];
      let currentIndex = 0;
      let totalSlots = 0;
      let totalRevenue = 0;
      let avgRevenuePerSlot = 0;
      
      // Extract total premium slots available
      const slotsMatch = lines.find(line => line.includes('Total premium slots available:'));
      const availableSlots = slotsMatch ? parseInt(slotsMatch.split(':')[1].trim()) : premiumSlots;
      
      // Find the line with "TIPDS Placement Results:" and start parsing from there
      const startIndex = lines.findIndex(line => line.includes('TIPDS Placement Results:'));
      
      if (startIndex !== -1) {
        // Parse each item entry
        for (let i = startIndex + 2; i < lines.length; i++) {
          const line = lines[i].trim();
          
          // Check if this is a numbered item line
          if (/^\d+\.\s+Items:/.test(line)) {
            const itemsLine = line;
            const slotsLine = lines[i + 1]?.trim();
            const revenueLine = lines[i + 2]?.trim();
            const revenuePerSlotLine = lines[i + 3]?.trim();
            
            if (slotsLine && revenueLine && revenuePerSlotLine) {
              // Extract item IDs
              const itemIds = itemsLine.split('Items:')[1].trim();
              
              // Extract slots used
              const slotsUsed = parseInt(slotsLine.split('Slots used:')[1].trim());
              
              // Extract net revenue
              const netRevenue = parseFloat(revenueLine.split('Net Revenue:')[1].trim());
              
              // Extract net revenue per slot
              const netRevPerSlot = parseFloat(revenuePerSlotLine.split('Net Revenue per Slot:')[1].trim());
              
              // Add to processed data
              processedItems.push({
                id: currentIndex++,
                itemId: itemIds,
                netRevPerSlot: netRevPerSlot,
                slotsUsed: slotsUsed,
                netRevenue: netRevenue,
                category: determineCategory(itemIds) // You may need to implement this function
              });
              
              // Skip to next item
              i += 3;
            }
          }
          
          // Extract summary information
          if (line.startsWith('Total slots used:')) {
            const parts = line.split(':')[1].trim().split('/');
            totalSlots = parseInt(parts[0]);
          }
          
          if (line.startsWith('Total expected revenue:')) {
            totalRevenue = parseFloat(line.split(':')[1].trim());
          }
          
          if (line.startsWith('Average revenue per slot:')) {
            avgRevenuePerSlot = parseFloat(line.split(':')[1].trim());
          }
        }
      }
      
      // Set the processed data
      setProcessedData(processedItems);
      
      // Set summary data
      setSummaryData({
        totalItems: processedItems.length,
        totalNetRevenue: totalRevenue,
        totalSlotsUsed: totalSlots,
        avgNetRevPerSlot: avgRevenuePerSlot,
        availableSlots
      });
    } catch (error) {
      console.error('Error parsing results:', error);
      setMessage('Error parsing results data.');
    }
  };
  
  // Simple function to assign categories based on item IDs
  // You may want to replace this with actual category data from your items file
  const determineCategory = (itemIds) => {
    const items = itemIds.split(',').map(item => item.trim());
    const categoryMap = {
      'Fruits and Vegetables': ['Apple', 'Banana', 'Cucumber', 'Garlic','Ginger'],
      'Personal Care': ['Dove', 'Sunsilk', 'Pears','Spinz','Vaseline','Parachute'],
      'Pantry Staples': ['TurDal', 'Rice', 'Wheat','Oil'],
      'Snacks': ['Bingo', 'Bread','Rusk','Boost'],
      'Beverages': ['ThumbsUp'],
      'Cosmetics': ['Compact', 'Lipstick', 'Foundation'],
      'Dairy Products': ['Milk'],
      'Stationary':['Books','Pens','Pencil']
    };
  
    const matchedCategories = [];
  
    for (const [category, categoryItems] of Object.entries(categoryMap)) {
      if (items.some(item => categoryItems.includes(item))) {
        matchedCategories.push(category);
      }
    }
  
    return matchedCategories.length > 0 ? matchedCategories.join(', ') : 'General';
  };
  
  

  // Drag and drop handlers
  const handleDragEnter = (e, type) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging({ ...isDragging, [type]: true });
  };

  const handleDragLeave = (e, type) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging({ ...isDragging, [type]: false });
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e, type) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging({ ...isDragging, [type]: false });

    const file = e.dataTransfer.files[0];
    if (file && file.name.endsWith('.csv')) {
      if (type === 'items') setItemsFile(file);
      if (type === 'transactions') setTransactionsFile(file);
      setMessage('');
    } else {
      setMessage('Please upload a valid CSV file.');
    }
  };

  // File handling functions
  const handleFileChange = (e, type) => {
    const file = e.target.files[0];
    if (file && file.name.endsWith('.csv')) {
      if (type === 'items') setItemsFile(file);
      if (type === 'transactions') setTransactionsFile(file);
      setMessage('');
    } else {
      setMessage('Please upload a valid CSV file.');
    }
  };

  const clearFile = (type) => {
    if (type === 'items') {
      setItemsFile(null);
      if (itemsInputRef.current) itemsInputRef.current.value = '';
    } else if (type === 'transactions') {
      setTransactionsFile(null);
      if (transactionsInputRef.current) transactionsInputRef.current.value = '';
    }
  };

  // Premium slots handler
  const handlePremiumSlotsChange = (e) => {
    const value = parseInt(e.target.value);
    if (!isNaN(value) && value > 0) {
      setPremiumSlots(value);
    }
  };

  // Upload and process function
  const handleUpload = async () => {
    if (!itemsFile || !transactionsFile) {
      setMessage('Please upload both CSV files.');
      return;
    }

    if (premiumSlots <= 0) {
      setMessage('Please enter a valid number of premium slots.');
      return;
    }

    setIsUploading(true);
    setMessage('');
    setResults(null);

    const formData = new FormData();
    formData.append('items', itemsFile);
    formData.append('transactions', transactionsFile);
    console.log('Premium Slots:', premiumSlots);
    formData.append('premiumSlots', premiumSlots); 

    try {
      const response = await fetch('http://localhost:4000/api/upload', {
        method: 'POST',
        body: formData,
      });

      const data = await response.json();
      setIsUploading(false);

      if (data.output) {
        setResults(data.output);
        setMessage('Processing completed successfully!');
      } else {
        setMessage(data.error || 'Processing failed.');
      }
    } catch (error) {
      setIsUploading(false);
      setMessage('Upload failed. Please try again.');
    }
  };

  // Calculate business metrics from data
  const calculateMetrics = () => {
    if (!summaryData) return {
      totalItems: 0,
      totalNetRevenue: 0,
      totalSlotsUsed: 0,
      avgNetRevPerSlot: 0,
      topCategories: []
    };
    
    // Aggregate by category
    const categorySummary = processedData.reduce((acc, item) => {
      if (!acc[item.category]) {
        acc[item.category] = {
          name: item.category,
          itemCount: 0,
          netRevenue: 0,
          slotsUsed: 0
        };
      }
      
      acc[item.category].itemCount++;
      acc[item.category].netRevenue += item.netRevenue;
      acc[item.category].slotsUsed += item.slotsUsed;
      
      return acc;
    }, {});
    
    // Convert to array and sort by revenue
    const topCategories = Object.values(categorySummary)
      .sort((a, b) => b.netRevenue - a.netRevenue)
      .slice(0, 5);
    
    return {
      totalItems: summaryData.totalItems,
      totalNetRevenue: summaryData.totalNetRevenue,
      totalSlotsUsed: summaryData.totalSlotsUsed,
      topCategories,
      avgNetRevPerSlot: summaryData.avgNetRevPerSlot
    };
  };

  const metrics = calculateMetrics();

  // Color mapping for visual elements
  const categoryColors = {
    'Electronics': '#4f46e5',
    'Clothing': '#10b981',
    'Home': '#eab308',
    'Food': '#f97316',
    'Books': '#ec4899',
    'General': '#6b7280'
  };

  // Get a consistent color for any category
  const getCategoryColor = (category) => {
    if (categoryColors[category]) return categoryColors[category];
    
    // Generate a consistent color for unknown categories
    const stringToColor = (str) => {
      let hash = 0;
      for (let i = 0; i < str.length; i++) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash);
      }
      let color = '#';
      for (let i = 0; i < 3; i++) {
        const value = (hash >> (i * 8)) & 0xFF;
        color += ('00' + value.toString(16)).substr(-2);
      }
      return color;
    };
    
    return stringToColor(category);
  };
  
  // Format currency
  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2
    }).format(amount);
  };

  // Export results
  const exportResults = () => {
    if (!results) return;
    
    const blob = new Blob([results], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'processed_data.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <div className="dashboard-page">
      <Header />
      
      {/* Decorative elements */}
      <div className="decorative-circle circle-1"></div>
      <div className="decorative-circle circle-2"></div>

      <div className="dashboard-content">

        <div className="dashboard-grid">
          {/* Upload Section */}
          <div className="upload-card">
            <div className="card-header">
              <h2>Upload Files</h2>
              <p>Select or drag &amp; drop your CSV files</p>
            </div>

            <div className="upload-area">
              {/* Items CSV Upload Zone */}
              <div
                className={`file-upload-zone ${isDragging.items ? 'dragging' : ''} ${
                  itemsFile ? 'has-file' : ''
                }`}
                onDragEnter={(e) => handleDragEnter(e, 'items')}
                onDragLeave={(e) => handleDragLeave(e, 'items')}
                onDragOver={handleDragOver}
                onDrop={(e) => handleDrop(e, 'items')}
                onClick={() => itemsInputRef.current.click()}
              >
                <input
                  type="file"
                  ref={itemsInputRef}
                  accept=".csv"
                  onChange={(e) => handleFileChange(e, 'items')}
                  hidden
                />

                {itemsFile ? (
                  <div className="selected-file-info">
                    <FiFile className="file-icon" />
                    <span className="file-name">{itemsFile.name}</span>
                    <span className="file-size">({(itemsFile.size / 1024).toFixed(2)} KB)</span>
                    <button
                      className="remove-file-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        clearFile('items');
                      }}
                    >
                      <FiX />
                    </button>
                  </div>
                ) : (
                  <div className="upload-placeholder">
                    <FiUpload className="upload-icon" />
                    <p>Upload Items CSV</p>
                    <span>Click or drag file here</span>
                  </div>
                )}
              </div>

              {/* Transactions CSV Upload Zone */}
              <div
                className={`file-upload-zone ${isDragging.transactions ? 'dragging' : ''} ${
                  transactionsFile ? 'has-file' : ''
                }`}
                onDragEnter={(e) => handleDragEnter(e, 'transactions')}
                onDragLeave={(e) => handleDragLeave(e, 'transactions')}
                onDragOver={handleDragOver}
                onDrop={(e) => handleDrop(e, 'transactions')}
                onClick={() => transactionsInputRef.current.click()}
              >
                <input
                  type="file"
                  ref={transactionsInputRef}
                  accept=".csv"
                  onChange={(e) => handleFileChange(e, 'transactions')}
                  hidden
                />

                {transactionsFile ? (
                  <div className="selected-file-info">
                    <FiFile className="file-icon" />
                    <span className="file-name">{transactionsFile.name}</span>
                    <span className="file-size">({(transactionsFile.size / 1024).toFixed(2)} KB)</span>
                    <button
                      className="remove-file-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        clearFile('transactions');
                      }}
                    >
                      <FiX />
                    </button>
                  </div>
                ) : (
                  <div className="upload-placeholder">
                    <FiUpload className="upload-icon" />
                    <p>Upload Transactions CSV</p>
                    <span>Click or drag file here</span>
                  </div>
                )}
              </div>
            </div>

            {/* Premium Slots Input */}
            <div className="premium-slots-section">
              <div className="premium-slots-header">
                <h3>
                  <FiLayers className="section-icon" />
                  Premium Slots Configuration
                </h3>
                <button 
                  className="advanced-toggle" 
                  onClick={() => setShowAdvancedSettings(!showAdvancedSettings)}
                >
                  <FiSliders />
                  {showAdvancedSettings ? 'Hide Advanced' : 'Show Advanced'}
                </button>
              </div>

              <div className="premium-slots-input-group">
                <label htmlFor="premium-slots">Number of Premium Slots:</label>
                <div className="slots-input-container">
                  <input
                    id="premium-slots"
                    type="number"
                    min="1"
                    value={premiumSlots}
                    onChange={handlePremiumSlotsChange}
                    className="premium-slots-input"
                  />
                  <div className="slot-controls">
                    <button 
                      className="slot-control-btn" 
                      onClick={() => setPremiumSlots(prev => Math.max(1, prev - 1))}
                    >
                      -
                    </button>
                    <button 
                      className="slot-control-btn" 
                      onClick={() => setPremiumSlots(prev => prev + 1)}
                    >
                      +
                    </button>
                  </div>
                </div>
                <div className="slots-description">
                  Set the number of premium display slots available for your product placement strategy
                </div>
              </div>

              {/* Advanced Settings (initially hidden) */}
              {showAdvancedSettings && (
                <div className="advanced-settings">
                  <div className="settings-row">
                    <div className="settings-group">
                      <label htmlFor="max-level">Max Level:</label>
                      <input id="max-level" type="number" defaultValue={10} min="1" />
                      <div className="setting-hint">Maximum grouping level for items</div>
                    </div>
                    
                    <div className="settings-group">
                      <label htmlFor="lambda-param">Lambda:</label>
                      <input id="lambda-param" type="number" defaultValue={10} min="1" />
                      <div className="setting-hint">Result limit per level</div>
                    </div>
                    
                  { /* <div className="settings-group">
                      <label htmlFor="alpha">Alpha (%):</label>
                      <input id="alpha" type="number" defaultValue={3} min="0" step="0.1" />
                      <div className="setting-hint">Threshold parameter</div>
                    </div> */}
                  </div>
                </div>
              )}
            </div>

            {/* Upload Button */}
            <div className="upload-actions">
              <button
                onClick={handleUpload}
                className={`upload-btn ${isUploading ? 'loading' : ''} ${
                  !itemsFile || !transactionsFile ? 'disabled' : ''
                }`}
                disabled={isUploading || !itemsFile || !transactionsFile}
              >
                {isUploading ? (
                  <>
                    <div className="spinner"></div>
                    Processing...
                  </>
                ) : (
                  'Process Data'
                )}
              </button>
            </div>

            {/* Feedback Message */}
            {message && (
              <div
                className={`message ${
                  message.includes('success') || message.includes('completed') ? 'success' : 'error'
                }`}
              >
                {message.includes('success') || message.includes('completed') ? (
                  <FiCheckCircle className="message-icon" />
                ) : (
                  <FiAlertTriangle className="message-icon" />
                )}
                <span>{message}</span>
              </div>
            )}
          </div>

          {/* Results Section */}
          <div className="results-card">
            <div className="card-header">
              <h2>Analysis Results</h2>
              <div className="card-actions">
                {results && (
                  <>
                    <div className="view-toggle">
                      <button 
                        className={`view-btn ${visualMode === 'grid' ? 'active' : ''}`}
                        onClick={() => setVisualMode('grid')}
                      >
                        <FiGrid />
                        <span>Grid</span>
                      </button>
                      <button 
                        className={`view-btn ${visualMode === 'chart' ? 'active' : ''}`}
                        onClick={() => setVisualMode('chart')}
                      >
                        <FiBarChart2 />
                        <span>Charts</span>
                      </button>
                    </div>
                    <button className="export-btn" onClick={exportResults} title="Export to CSV">
                      <FiDownload />
                      <span>Export</span>
                    </button>
                  </>
                )}
              </div>
            </div>

            {results ? (
              <div className="results-container">
                {/* Key Metrics */}
                <div className="metrics-grid">
                  <div className="metric-card revenue">
                    <div className="metric-icon">
                      <FiDollarSign />
                    </div>
                    <div className="metric-content">
                      <h3>Net Revenue</h3>
                      <div className="metric-value">{formatCurrency(metrics.totalNetRevenue)}</div>
                      <div className="metric-label">Total Sales</div>
                    </div>
                  </div>
                  
                  <div className="metric-card items">
                    <div className="metric-icon">
                      <FiBox />
                    </div>
                    <div className="metric-content">
                      <h3>Total Items</h3>
                      <div className="metric-value">{metrics.totalItems.toLocaleString()}</div>
                      <div className="metric-label">Unique Groups</div>
                    </div>
                  </div>
                  
                  <div className="metric-card transactions">
                    <div className="metric-icon">
                      <FiShoppingCart />
                    </div>
                    <div className="metric-content">
                      <h3>Slots Used</h3>
                      <div className="metric-value">{metrics.totalSlotsUsed.toLocaleString()}</div>
                      <div className="metric-label">of {premiumSlots} Available</div>
                    </div>
                  </div>
                  
                  <div className="metric-card average">
                    <div className="metric-icon">
                      <FiBarChart2 />
                    </div>
                    <div className="metric-content">
                      <h3>Net Rev Per Slot</h3>
                      <div className="metric-value">{formatCurrency(metrics.avgNetRevPerSlot)}</div>
                      <div className="metric-label">Average</div>
                    </div>
                  </div>
                </div>

                {visualMode === 'grid' ? (
                  /* Grid View of Items */
                  <div className="data-grid">
                    <table className="data-table">
                      <thead>
                        <tr>
                          <th>Item Group</th>
                          <th>Category</th>
                          <th>Slots Used</th>
                          <th>Net Revenue</th>
                          <th>Net Rev Per Slot</th>
                        </tr>
                      </thead>
                      <tbody>
                        {processedData.map((item) => (
                          <tr key={item.id}>
                            <td>
                              <div className="item-id-cell">
                                <span className="item-id">{item.itemId}</span>
                              </div>
                            </td>
                            <td>
                              <span className="category-badge" style={{ backgroundColor: getCategoryColor(item.category) }}>
                                {item.category}
                              </span>
                            </td>
                            <td>{item.slotsUsed.toLocaleString()}</td>
                            <td>{formatCurrency(item.netRevenue)}</td>
                            <td className="revenue-cell">{formatCurrency(item.netRevPerSlot)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  /* Chart View */
                  <div className="chart-container">
                    {/* Category Revenue Chart */}
                    <div className="chart-section">
                      <h3 className="chart-title">Net Revenue by Category</h3>
                      <div className="bar-chart">
                        {metrics.topCategories.map((category, index) => (
                          <div className="chart-row" key={index}>
                            <div className="chart-label">
                              <span className="color-dot" style={{ backgroundColor: getCategoryColor(category.name) }}></span>
                              <span>{category.name}</span>
                            </div>
                            <div className="chart-bar-container">
                              <div 
                                className="chart-bar" 
                                style={{ 
                                  width: `${(category.netRevenue / metrics.totalNetRevenue) * 100}%`,
                                  backgroundColor: getCategoryColor(category.name)
                                }} 
                              ></div>
                              <span className="bar-value">{formatCurrency(category.netRevenue)}</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                    
                    {/* Top Items */}
                    <div className="chart-section">
                      <h3 className="chart-title">Top Items by Net Revenue</h3>
                      <div className="top-items">
                        {processedData
                          .sort((a, b) => b.netRevenue - a.netRevenue)
                          .slice(0, 5)
                          .map((item, index) => (
                            <div className="top-item" key={index}>
                              <div className="top-item-rank">{index + 1}</div>
                              <div className="top-item-details">
                                <div className="top-item-id">{item.itemId}</div>
                                <div className="top-item-category">{item.category}</div>
                              </div>
                              <div className="top-item-stats">
                                <div className="top-item-quantity">{item.slotsUsed} slots</div>
                                <div className="top-item-revenue">{formatCurrency(item.netRevenue)}</div>
                              </div>
                            </div>
                          ))}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="empty-state">
                <div className="empty-icon">
                  <FiBarChart2 size={48} />
                </div>
                <h3>No Data Available</h3>
                <p>Upload your CSV files and process them to view analysis results</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;