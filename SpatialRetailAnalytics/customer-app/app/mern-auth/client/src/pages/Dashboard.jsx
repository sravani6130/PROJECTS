import React, { useState, useEffect } from 'react';
import {
  Trophy,
  Gift,
  Share2,
  Bell,
  MapPin,
  Target,
  Award,
  TrendingUp,
  Zap,
  ShoppingBag,
  Star,
  ChevronRight,
  Ticket,
  Lock,
  Check,
  X,
  Sparkles
} from 'lucide-react';

const Dashboard = () => {
  // Navigation
  const [currentPage, setCurrentPage] = useState('dashboard');

  // Core states
  const [activeTab, setActiveTab] = useState('overview');
  const [points, setPoints] = useState(1250);
  const [level, setLevel] = useState(5);
  const [animated, setAnimated] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [shareModal, setShareModal] = useState(null);

  // Coupons feature states
  const [purchaseModal, setPurchaseModal] = useState(null);
  const [ownedCoupons, setOwnedCoupons] = useState([]);

  // Other states from your original Dashboard
  const [restockAlerts, setRestockAlerts] = useState([
    { id: 1, product: 'Wireless Headphones Pro', zone: 'Electronics', status: 'Available Now', inStock: true },
    { id: 2, product: 'Designer Handbag', zone: 'Fashion', status: 'Back in 2 days', inStock: false },
    { id: 3, product: 'Smart Coffee Maker', zone: 'Home', status: 'Low Stock', inStock: true },
  ]);

  useEffect(() => {
    setAnimated(true);
  }, []);

  // Notification helper
  const showNotification = (message, type) => {
    const newNotif = { id: Date.now(), message, type };
    setNotifications(prev => [...prev, newNotif]);
    setTimeout(() => {
      setNotifications(prev => prev.filter(n => n.id !== newNotif.id));
    }, 3000);
  };

  // Share logic (keeps your original behavior)
  const handleShare = (platform, offer) => {
    const text = `🎉 Amazing Deal Alert! ${offer.title} - ${offer.discount} OFF! 
${offer.desc}
⏰ Expires in ${offer.expires}

Grab it now before it's gone! 🛍️`;
    const encodedText = encodeURIComponent(text);

    if (platform === 'whatsapp') {
      window.open(`https://wa.me/?text=${encodedText}`, '_blank');
      earnSharePoints(50);
    } else if (platform === 'instagram') {
      navigator.clipboard.writeText(text);
      alert('✅ Copied to clipboard! Now you can share it on Instagram Stories or Posts!');
      earnSharePoints(50);
    }
    setShareModal(null);
  };

  const earnSharePoints = (amount) => {
    setPoints(prev => prev + amount);
    showNotification(`+${amount} points earned for sharing!`, 'success');
  };

  const subscribeToRestock = (product) => {
    showNotification(`🔔 You'll be notified when ${product} is back in stock!`, 'info');
  };

  // Stats, challenges, offers, recommendations, etc - kept from your original Dashboard
  const stats = [
    { icon: Trophy, label: 'Total Points', value: points, color: '#06b6d4', gradient: 'from-cyan-400 to-blue-500' },
    { icon: Award, label: 'Achievements', value: 12, color: '#f59e0b', gradient: 'from-amber-400 to-orange-500' },
    { icon: ShoppingBag, label: 'Completed', value: 24, color: '#10b981', gradient: 'from-emerald-400 to-green-500' },
    { icon: Star, label: 'Level', value: level, color: '#8b5cf6', gradient: 'from-purple-400 to-violet-500' },
  ];

  const challenges = [
    { id: 1, title: 'Electronics Explorer', desc: 'Visit Electronics Zone 3 times', progress: 66, reward: 150, zone: 'Electronics', color: '#3b82f6' },
    { id: 2, title: 'Fashion Forward', desc: 'Try 5 items in Fashion Zone', progress: 80, reward: 200, zone: 'Fashion', color: '#ec4899' },
    { id: 3, title: 'Home Essentials', desc: 'Complete Home Zone purchase', progress: 40, reward: 120, zone: 'Home', color: '#10b981' },
  ];

  const offers = [
    { id: 1, title: '25% OFF Electronics', desc: 'Limited time offer on your favorite gadgets', expires: '2 hours', discount: '25%', color: '#3b82f6', zone: 'Electronics' },
    { id: 2, title: 'Fashion Flash Sale', desc: 'Exclusive discount on trending apparel', expires: '5 hours', discount: '30%', color: '#ec4899', zone: 'Fashion' },
    { id: 3, title: 'Home Decor Deal', desc: 'Special prices on home essentials', expires: '1 day', discount: '20%', color: '#10b981', zone: 'Home' },
  ];

  const aiRecommendations = [
    { id: 1, product: 'Wireless Earbuds Pro', price: 129.99, discount: 35, image: '🎧', confidence: 95, reason: 'Based on your recent electronics browsing' },
    { id: 2, product: 'Yoga Mat Premium', price: 49.99, discount: 25, image: '🧘', confidence: 88, reason: 'Popular in your favorite zone' },
    { id: 3, product: 'Smart Watch Series 5', price: 299.99, discount: 40, image: '⌚', confidence: 92, reason: 'Trending in your area' },
  ];

  const socialStats = {
    totalShares: 24,
    pointsEarned: 1200,
    followers: 156,
    trending: '#ShopSmart2024'
  };

  const recentActivity = [
    { action: 'Completed challenge', item: 'Tech Enthusiast', points: '+150', time: '2h ago', icon: Trophy },
    { action: 'Shared product', item: 'Wireless Headphones', points: '+50', time: '5h ago', icon: Share2 },
    { action: 'Unlocked badge', item: 'Shopping Streak', points: '+100', time: '1d ago', icon: Award },
    { action: 'Redeemed offer', item: '15% Electronics Discount', points: '-200', time: '2d ago', icon: Gift },
  ];

  const badges = [
    { name: 'First Steps', icon: '🎯', unlocked: true },
    { name: 'Social Star', icon: '⭐', unlocked: true },
    { name: 'Zone Master', icon: '🏆', unlocked: true },
    { name: 'Deal Hunter', icon: '💎', unlocked: false },
    { name: 'Shopping Pro', icon: '👑', unlocked: false },
    { name: 'Legend', icon: '🔥', unlocked: false },
  ];

  // Coupons data (copied/adapted from the first code you showed)
  const coupons = [
    { id: 1, name: '20% OFF Electronics', discount: '20%', category: 'Electronics', cost: 500, color: '#3b82f6', icon: '💻', rarity: 'Common' },
    { id: 2, name: '35% OFF Fashion', discount: '35%', category: 'Fashion', cost: 800, color: '#ec4899', icon: '👗', rarity: 'Rare' },
    { id: 3, name: '15% OFF Groceries', discount: '15%', category: 'Groceries', cost: 300, color: '#10b981', icon: '🛒', rarity: 'Common' },
    { id: 4, name: '50% OFF Home Decor', discount: '50%', category: 'Home Decor', cost: 1200, color: '#f59e0b', icon: '🏠', rarity: 'Epic' },
    { id: 5, name: 'Buy 1 Get 1 Free', discount: 'BOGO', category: 'All Categories', cost: 1500, color: '#8b5cf6', icon: '🎁', rarity: 'Legendary' },
    { id: 6, name: '25% OFF Sports', discount: '25%', category: 'Sports', cost: 600, color: '#06b6d4', icon: '⚽', rarity: 'Rare' },
  ];

  const rarityColors = {
    'Common': '#64748b',
    'Rare': '#3b82f6',
    'Epic': '#a855f7',
    'Legendary': '#f59e0b'
  };

  // Purchase coupon logic
  const purchaseCoupon = (coupon) => {
    if (points >= coupon.cost) {
      setPoints(prev => prev - coupon.cost);
      setOwnedCoupons(prev => [...prev, { ...coupon, purchaseDate: new Date() }]);
      showNotification(`✅ Coupon purchased! ${coupon.discount} off ${coupon.category}`, 'success');
      setPurchaseModal(null);
    } else {
      showNotification(`❌ Not enough points! Need ${coupon.cost - points} more`, 'error');
    }
  };

  // Render - if coupons page is active show the coupons marketplace (mimic the first code behavior)
  if (currentPage === 'coupons') {
    return (
     <div style={{ ...styles.container, marginTop: '190px' }}>
        {/* Notification Toast */}
        <div style={styles.notificationContainer}>
          {notifications.map(notif => (
            <div key={notif.id} style={{...styles.notification, ...styles[`notification${notif.type}`]}}>
              {notif.message}
            </div>
          ))}
        </div>

        {/* Purchase Modal */}
        {purchaseModal && (
          <div style={styles.modalOverlay} onClick={() => setPurchaseModal(null)}>
            <div style={styles.modal} onClick={e => e.stopPropagation()}>
              <div style={{textAlign: 'center'}}>
                <div style={{fontSize: '4rem', marginBottom: '16px'}}>{purchaseModal.icon}</div>
                <h3 style={styles.modalTitle}>Purchase Coupon?</h3>
                <div style={{...styles.rarityBadge, background: rarityColors[purchaseModal.rarity], marginBottom: '16px'}}>
                  {purchaseModal.rarity}
                </div>
                <h4 style={{fontSize: '1.25rem', fontWeight: '700', color: '#0c4a6e', marginBottom: '8px'}}>
                  {purchaseModal.name}
                </h4>
                <p style={{color: '#64748b', marginBottom: '24px'}}>
                  Get {purchaseModal.discount} off on {purchaseModal.category}
                </p>
                <div style={styles.costDisplay}>
                  <Trophy size={24} color="#f59e0b" />
                  <span style={{fontSize: '2rem', fontWeight: '700', color: '#0c4a6e'}}>
                    {purchaseModal.cost}
                  </span>
                  <span style={{color: '#64748b'}}>points</span>
                </div>
                <div style={{marginTop: '24px', fontSize: '0.875rem', color: points >= purchaseModal.cost ? '#10b981' : '#ef4444', fontWeight: '600'}}>
                  {points >= purchaseModal.cost ? '✓ You have enough points!' : `Need ${purchaseModal.cost - points} more points`}
                </div>
              </div>
              <div style={{display: 'flex', gap: '12px', marginTop: '24px'}}>
                <button 
                  style={{...styles.modalBtn, background: 'linear-gradient(135deg, #10b981, #059669)', opacity: points >= purchaseModal.cost ? 1 : 0.5}}
                  onClick={() => purchaseCoupon(purchaseModal)}
                  disabled={points < purchaseModal.cost}
                >
                  <Check size={20} />
                  Purchase
                </button>
                <button 
                  style={{...styles.modalBtn, background: '#e2e8f0', color: '#64748b'}}
                  onClick={() => setPurchaseModal(null)}
                >
                  <X size={20} />
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Header */}
        <div style={styles.couponsHeader}>
          <button style={styles.backBtn} onClick={() => setCurrentPage('dashboard')}>
            ← Back to Dashboard
          </button>
          <h1 style={styles.couponsTitle}>
            <Sparkles size={32} color="#f59e0b" />
            Coupon Marketplace
          </h1>
          <div style={styles.pointsDisplay}>
            <Trophy size={24} color="#f59e0b" />
            <span style={styles.pointsValue}>{points}</span>
            <span style={styles.pointsLabel}>points</span>
          </div>
        </div>

        {/* Owned Coupons */}
        {ownedCoupons.length > 0 && (
          <div style={styles.section}>
            <h2 style={styles.sectionTitle}>
              <Gift size={24} color="#10b981" />
              My Coupons ({ownedCoupons.length})
            </h2>
            <div style={styles.couponsGrid}>
              {ownedCoupons.map((coupon, index) => (
                <div key={index} style={{...styles.ownedCouponCard, borderColor: coupon.color}}>
                  <div style={styles.ownedBadge}>OWNED</div>
                  <div style={styles.couponIcon}>{coupon.icon}</div>
                  <h3 style={styles.couponName}>{coupon.name}</h3>
                  <div style={styles.couponDiscount}>{coupon.discount}</div>
                  <p style={styles.couponCategory}>{coupon.category}</p>
                  <button style={{...styles.useCouponBtn, background: coupon.color}}>
                    Use Coupon
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Available Coupons */}
        <div style={styles.section}>
          <h2 style={styles.sectionTitle}>
            <Ticket size={24} color="#06b6d4" />
            Available Coupons
          </h2>
          <div style={styles.couponsGrid}>
            {coupons.map((coupon) => {
              const isOwned = ownedCoupons.some(c => c.id === coupon.id);
              const canAfford = points >= coupon.cost;

              return (
                <div 
                  key={coupon.id} 
                  style={{
                    ...styles.couponCard,
                    borderColor: coupon.color,
                    opacity: isOwned ? 0.6 : 1
                  }}
                  className="couponCard"
                >
                  {isOwned && (
                    <div style={styles.ownedOverlay}>
                      <Check size={32} color="white" />
                      <span>OWNED</span>
                    </div>
                  )}
                  <div style={{...styles.rarityBadge, background: rarityColors[coupon.rarity]}}>
                    {coupon.rarity}
                  </div>
                  <div style={styles.couponIcon}>{coupon.icon}</div>
                  <h3 style={styles.couponName}>{coupon.name}</h3>
                  <div style={styles.couponDiscount}>{coupon.discount}</div>
                  <p style={styles.couponCategory}>{coupon.category}</p>
                  <div style={styles.couponCost}>
                    <Trophy size={16} color="#f59e0b" />
                    <span>{coupon.cost} points</span>
                  </div>
                  <button 
                    style={{
                      ...styles.purchaseBtn,
                      background: isOwned ? '#94a3b8' : (canAfford ? coupon.color : '#e2e8f0'),
                      color: isOwned || !canAfford ? '#64748b' : 'white',
                      cursor: isOwned ? 'not-allowed' : (canAfford ? 'pointer' : 'not-allowed')
                    }}
                    onClick={() => !isOwned && canAfford && setPurchaseModal(coupon)}
                    disabled={isOwned || !canAfford}
                  >
                    {isOwned ? (
                      <>
                        <Check size={16} />
                        Owned
                      </>
                    ) : canAfford ? (
                      <>
                        <ShoppingBag size={16} />
                        Purchase
                      </>
                    ) : (
                      <>
                        <Lock size={16} />
                        Need {coupon.cost - points} more
                      </>
                    )}
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Default Dashboard render (same as your original but with a "Coupons" button to navigate)
  return (
    <div style={styles.container}>
      {/* Notification Toast */}
      <div style={styles.notificationContainer}>
        {notifications.map(notif => (
          <div key={notif.id} style={{...styles.notification, ...styles[`notification${notif.type}`]}}>
            {notif.message}
          </div>
        ))}
      </div>

      {/* Share Modal */}
      {shareModal && (
        <div style={styles.modalOverlay} onClick={() => setShareModal(null)}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Share & Earn 50 Points! 🎉</h3>
            <div style={styles.sharePreview}>
              <div style={{...styles.offerDiscount, background: shareModal.color}}>
                {shareModal.discount}
              </div>
              <h4>{shareModal.title}</h4>
              <p>{shareModal.desc}</p>
            </div>
            <div style={styles.shareButtons}>
              <button 
                style={{...styles.shareBtn, background: '#25D366'}}
                onClick={() => handleShare('whatsapp', shareModal)}
              >
                <span style={{fontSize: '24px'}}>📱</span>
                Share on WhatsApp
              </button>
              <button 
                style={{...styles.shareBtn, background: 'linear-gradient(45deg, #f09433 0%,#e6683c 25%,#dc2743 50%,#cc2366 75%,#bc1888 100%)'}}
                onClick={() => handleShare('instagram', shareModal)}
              >
                <span style={{fontSize: '24px'}}>📷</span>
                Share on Instagram
              </button>
            </div>
            <button style={styles.closeModalBtn} onClick={() => setShareModal(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Header */}
      <div style={styles.header}>
        <div style={styles.headerContent}>
          <div>
            <h1 style={styles.headerTitle}>Welcome Back, Neha! 🎉</h1>
            <p style={styles.headerSubtitle}>Your personalized shopping journey continues</p>
          </div>
          <div style={styles.headerActions}>
            <button style={styles.couponsPageBtn} onClick={() => setCurrentPage('coupons')}>
              <Ticket size={20} />
              Coupons
            </button>
            <button style={styles.notificationBtn} className="notificationBtn">
              <Bell size={20} />
              <span style={styles.badge}>3</span>
            </button>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div style={styles.statsGrid} className="statsGrid">
        {stats.map((stat, index) => (
          <div
            key={index}
            className="statCard"
            style={{
              ...styles.statCard,
              animationDelay: `${index * 0.1}s`,
              opacity: animated ? 1 : 0,
            }}
          >
            <div style={styles.statIconWrapper}>
              <div style={{ ...styles.statIcon, background: `linear-gradient(135deg, ${stat.color}, ${stat.color}dd)` }}>
                <stat.icon size={24} color="white" />
              </div>
            </div>
            <div style={styles.statInfo}>
              <p style={styles.statLabel}>{stat.label}</p>
              <p style={styles.statValue}>{stat.value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Main Content */}
      <div style={styles.mainContent} className="mainContent">
        {/* Left Column */}
        <div style={styles.leftColumn}>
          {/* Active Challenges */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Target size={24} color="#06b6d4" />
                <h2 style={styles.sectionTitle}>Active Challenges</h2>
              </div>
              <button style={styles.viewAllBtn} className="viewAllBtn">
                View All <ChevronRight size={16} />
              </button>
            </div>
            <div style={styles.challengesContainer}>
              {challenges.map((challenge) => (
                <div key={challenge.id} style={styles.challengeCard} className="challengeCard">
                  <div style={styles.challengeHeader}>
                    <div>
                      <h3 style={styles.challengeTitle}>{challenge.title}</h3>
                      <p style={styles.challengeDesc}>{challenge.desc}</p>
                    </div>
                    <div style={styles.rewardBadge}>
                      <Zap size={14} color="#f59e0b" />
                      <span>{challenge.reward}</span>
                    </div>
                  </div>
                  <div style={styles.progressContainer}>
                    <div style={styles.progressBar}>
                      <div 
                        style={{
                          ...styles.progressFill,
                          width: `${challenge.progress}%`,
                          background: challenge.color,
                        }}
                      />
                    </div>
                    <span style={styles.progressText}>{challenge.progress}%</span>
                  </div>
                  <div style={styles.challengeFooter}>
                    <span style={{ ...styles.zoneTag, background: `${challenge.color}15`, color: challenge.color }}>
                      <MapPin size={12} />
                      {challenge.zone}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Personalized Offers */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Gift size={24} color="#ec4899" />
                <h2 style={styles.sectionTitle}>Personalized Offers</h2>
              </div>
              <button style={styles.viewAllBtn} className="viewAllBtn">
                View All <ChevronRight size={16} />
              </button>
            </div>
            <div style={styles.offersGrid} className="offersGrid">
              {offers.map((offer) => (
                <div key={offer.id} style={styles.offerCard} className="offerCard">
                  <div style={{ ...styles.offerDiscount, background: offer.color }}>
                    {offer.discount}
                  </div>
                  <h3 style={styles.offerTitle}>{offer.title}</h3>
                  <p style={styles.offerDesc}>{offer.desc}</p>
                  <div style={styles.offerFooter}>
                    <span style={styles.expiryText}>
                      ⏰ Expires in {offer.expires}
                    </span>
                    <div style={{display: 'flex', gap: '8px'}}>
                      <button 
                        style={{ ...styles.shareSmallBtn, background: offer.color }}
                        className="shareBtn"
                        onClick={() => setShareModal(offer)}
                        title="Share & Earn Points"
                      >
                        <Share2 size={14} />
                      </button>
                      <button style={{ ...styles.claimBtn, background: offer.color }}>
                        Claim Now
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Recommendations */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Zap size={24} color="#f59e0b" />
                <h2 style={styles.sectionTitle}>AI Recommendations For You</h2>
              </div>
            </div>
            <div style={styles.recommendationsGrid}>
              {aiRecommendations.map((rec) => (
                <div key={rec.id} style={styles.recommendationCard} className="recommendationCard">
                  <div style={styles.recImage}>{rec.image}</div>
                  <div style={styles.recContent}>
                    <h4 style={styles.recTitle}>{rec.product}</h4>
                    <p style={styles.recReason}>💡 {rec.reason}</p>
                    <div style={styles.recPricing}>
                      <span style={styles.recPrice}>${rec.price}</span>
                      <span style={styles.recDiscount}>{rec.discount}% OFF</span>
                    </div>
                    <div style={styles.recFooter}>
                      <div style={styles.confidenceBadge}>
                        <Star size={12} color="#f59e0b" />
                        <span>{rec.confidence}% Match</span>
                      </div>
                      <button style={styles.recViewBtn} className="recViewBtn">View Deal</button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right Column */}
        <div style={styles.rightColumn}>
          {/* Level Progress */}
          <div style={styles.levelCard}>
            <div style={styles.levelHeader}>
              <h3 style={styles.levelTitle}>Level {level} Explorer</h3>
              <span style={styles.levelNext}>Next: Level {level + 1}</span>
            </div>
            <div style={styles.levelProgressContainer}>
              <div style={styles.levelProgressBar}>
                <div style={styles.levelProgressFill} />
              </div>
              <p style={styles.levelProgressText}>350 / 500 XP</p>
            </div>
          </div>

          {/* Badges */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Award size={24} color="#8b5cf6" />
                <h2 style={styles.sectionTitle}>Achievements</h2>
              </div>
            </div>
            <div style={styles.badgesGrid} className="badgesGrid">
              {badges.map((badge, index) => (
                <div
                  key={index}
                  style={{
                    ...styles.badgeCard,
                    opacity: badge.unlocked ? 1 : 0.4,
                  }}
                >
                  <div style={styles.badgeIcon}>{badge.icon}</div>
                  <p style={styles.badgeName}>{badge.name}</p>
                  {badge.unlocked && <div style={styles.unlockedIndicator}>✓</div>}
                </div>
              ))}
            </div>
          </div>

          {/* Recent Activity */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <TrendingUp size={24} color="#10b981" />
                <h2 style={styles.sectionTitle}>Recent Activity</h2>
              </div>
            </div>
            <div style={styles.activityList}>
              {recentActivity.map((activity, index) => (
                <div key={index} style={styles.activityItem}>
                  <div style={styles.activityIcon}>
                    <activity.icon size={16} />
                  </div>
                  <div style={styles.activityContent}>
                    <p style={styles.activityAction}>{activity.action}</p>
                    <p style={styles.activityItemText}>{activity.item}</p>
                  </div>
                  <div style={styles.activityRight}>
                    <span style={styles.activityPoints}>{activity.points}</span>
                    <span style={styles.activityTime}>{activity.time}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Social Sharing Stats */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Share2 size={24} color="#ec4899" />
                <h2 style={styles.sectionTitle}>Social Rewards</h2>
              </div>
            </div>
            <div style={styles.socialStatsGrid} className="socialStatsGrid">
              <div style={styles.socialStatCard}>
                <div style={styles.socialStatIcon}>📱</div>
                <div style={styles.socialStatValue}>{socialStats.totalShares}</div>
                <div style={styles.socialStatLabel}>Total Shares</div>
              </div>
              <div style={styles.socialStatCard}>
                <div style={styles.socialStatIcon}>⚡</div>
                <div style={styles.socialStatValue}>{socialStats.pointsEarned}</div>
                <div style={styles.socialStatLabel}>Points Earned</div>
              </div>
              <div style={styles.socialStatCard}>
                <div style={styles.socialStatIcon}>👥</div>
                <div style={styles.socialStatValue}>{socialStats.followers}</div>
                <div style={styles.socialStatLabel}>Followers</div>
              </div>
            </div>
            <div style={styles.trendingTag}>
              🔥 Trending: {socialStats.trending}
            </div>
          </div>

          {/* Smart Restocking Alerts */}
          <div style={styles.section}>
            <div style={styles.sectionHeader}>
              <div style={styles.sectionTitleWrapper}>
                <Bell size={24} color="#3b82f6" />
                <h2 style={styles.sectionTitle}>Restock Alerts</h2>
              </div>
            </div>
            <div style={styles.restockList}>
              {restockAlerts.map((alert) => (
                <div key={alert.id} style={styles.restockItem}>
                  <div style={styles.restockInfo}>
                    <h4 style={styles.restockProduct}>{alert.product}</h4>
                    <p style={styles.restockZone}>📍 {alert.zone}</p>
                    <div style={{
                      ...styles.restockStatus,
                      background: alert.inStock ? '#d1fae5' : '#fee2e2',
                      color: alert.inStock ? '#065f46' : '#991b1b'
                    }}>
                      {alert.inStock ? '✓' : '⏰'} {alert.status}
                    </div>
                  </div>
                  <button 
                    style={styles.restockBtn}
                    className="restockBtn"
                    onClick={() => subscribeToRestock(alert.product)}
                  >
                    {alert.inStock ? 'View' : 'Notify Me'}
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

/* ---------- Styles (kept inline object style like your original; extended for coupons) ---------- */
const styles = {
  container: {
    minHeight: '100vh',
    width: '100vw',
    background: 'linear-gradient(to bottom right, #ecfeff, #eff6ff, #f8fafc)',
    padding: '24px',
    fontFamily: "'Inter', sans-serif",
    marginTop: '1190px'
  },
  header: {
    background: 'white',
    borderRadius: '20px',
    padding: '32px',
    marginBottom: '24px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.06)',
    border: '1px solid rgba(226, 232, 240, 0.8)',
  },
  headerContent: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '16px',
  },
  headerTitle: {
    fontSize: 'clamp(1.5rem, 3vw, 2rem)',
    fontWeight: '700',
    color: '#0c4a6e',
    marginBottom: '8px',
  },
  headerSubtitle: {
    color: '#64748b',
    fontSize: '1rem',
  },
  headerActions: {
    display: 'flex',
    gap: '12px',
  },
  couponsPageBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '12px 20px',
    borderRadius: '12px',
    border: 'none',
    background: 'linear-gradient(135deg, #10b981, #059669)',
    color: 'white',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'transform 0.2s',
    boxShadow: '0 4px 12px rgba(16, 185, 129, 0.3)',
  },
  notificationBtn: {
    position: 'relative',
    width: '48px',
    height: '48px',
    borderRadius: '50%',
    border: 'none',
    background: 'linear-gradient(135deg, #06b6d4, #3b82f6)',
    color: 'white',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'transform 0.2s',
    boxShadow: '0 4px 12px rgba(6, 182, 212, 0.3)',
  },
  badge: {
    position: 'absolute',
    top: '-4px',
    right: '-4px',
    background: '#ef4444',
    color: 'white',
    borderRadius: '50%',
    width: '20px',
    height: '20px',
    fontSize: '11px',
    fontWeight: '700',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: '2px solid white',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
    gap: '20px',
    marginBottom: '24px',
  },
  statCard: {
    background: 'white',
    borderRadius: '16px',
    padding: '24px',
    display: 'flex',
    alignItems: 'center',
    gap: '16px',
    boxShadow: '0 4px 16px rgba(0, 0, 0, 0.06)',
    border: '1px solid rgba(226, 232, 240, 0.8)',
    animation: 'slideUp 0.6s ease-out forwards',
    transition: 'transform 0.3s, box-shadow 0.3s',
    cursor: 'pointer',
  },
  statIconWrapper: {
    position: 'relative',
  },
  statIcon: {
    width: '56px',
    height: '56px',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow: '0 8px 16px rgba(0, 0, 0, 0.1)',
  },
  statInfo: {
    flex: 1,
  },
  statLabel: {
    color: '#64748b',
    fontSize: '0.875rem',
    marginBottom: '4px',
  },
  statValue: {
    fontSize: '1.75rem',
    fontWeight: '700',
    color: '#0c4a6e',
  },
  mainContent: {
    display: 'grid',
    gridTemplateColumns: '1fr 380px',
    gap: '24px',
  },
  leftColumn: {
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
  },
  rightColumn: {
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
  },
  section: {
    background: 'white',
    borderRadius: '20px',
    padding: '28px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.06)',
    border: '1px solid rgba(226, 232, 240, 0.8)',
  },
  sectionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
  },
  sectionTitleWrapper: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  sectionTitle: {
    fontSize: '1.25rem',
    fontWeight: '700',
    color: '#0c4a6e',
  },
  viewAllBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    background: 'none',
    border: 'none',
    color: '#06b6d4',
    fontWeight: '600',
    fontSize: '0.875rem',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  },
  challengesContainer: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  challengeCard: {
    padding: '20px',
    borderRadius: '12px',
    background: 'linear-gradient(135deg, #f8fafc, #ffffff)',
    border: '1px solid #e2e8f0',
    transition: 'all 0.3s',
    cursor: 'pointer',
  },
  challengeHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '16px',
    gap: '12px',
  },
  challengeTitle: {
    fontSize: '1rem',
    fontWeight: '600',
    color: '#0c4a6e',
    marginBottom: '4px',
  },
  challengeDesc: {
    fontSize: '0.875rem',
    color: '#64748b',
  },
  rewardBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    background: '#fef3c7',
    padding: '6px 12px',
    borderRadius: '20px',
    fontSize: '0.875rem',
    fontWeight: '600',
    color: '#92400e',
    whiteSpace: 'nowrap',
  },
  progressContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '12px',
  },
  progressBar: {
    flex: 1,
    height: '8px',
    background: '#e2e8f0',
    borderRadius: '4px',
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: '4px',
    transition: 'width 0.6s ease-out',
  },
  progressText: {
    fontSize: '0.875rem',
    fontWeight: '600',
    color: '#64748b',
    minWidth: '40px',
  },
  challengeFooter: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  zoneTag: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    padding: '4px 10px',
    borderRadius: '12px',
    fontSize: '0.75rem',
    fontWeight: '600',
  },
  offersGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: '16px',
  },
  offerCard: {
    position: 'relative',
    padding: '20px',
    borderRadius: '12px',
    background: 'linear-gradient(135deg, #f8fafc, #ffffff)',
    border: '1px solid #e2e8f0',
    transition: 'all 0.3s',
    cursor: 'pointer',
  },
  offerDiscount: {
    position: 'absolute',
    top: '12px',
    right: '12px',
    color: 'white',
    padding: '6px 12px',
    borderRadius: '8px',
    fontSize: '0.875rem',
    fontWeight: '700',
  },
  offerTitle: {
    fontSize: '1rem',
    fontWeight: '600',
    color: '#0c4a6e',
    marginBottom: '8px',
    marginRight: '60px',
  },
  offerDesc: {
    fontSize: '0.875rem',
    color: '#64748b',
    marginBottom: '16px',
    lineHeight: '1.5',
  },
  offerFooter: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
    flexWrap: 'wrap',
  },
  expiryText: {
    fontSize: '0.75rem',
    color: '#64748b',
    fontWeight: '500',
  },
  claimBtn: {
    padding: '8px 16px',
    borderRadius: '20px',
    border: 'none',
    color: 'white',
    fontSize: '0.875rem',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  },
  levelCard: {
    background: 'linear-gradient(135deg, #06b6d4, #3b82f6)',
    borderRadius: '20px',
    padding: '28px',
    color: 'white',
    boxShadow: '0 8px 24px rgba(6, 182, 212, 0.3)',
  },
  levelHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
  },
  levelTitle: {
    fontSize: '1.5rem',
    fontWeight: '700',
  },
  levelNext: {
    fontSize: '0.875rem',
    opacity: 0.9,
  },
  levelProgressContainer: {
    marginTop: '16px',
  },
  levelProgressBar: {
    height: '12px',
    background: 'rgba(255, 255, 255, 0.2)',
    borderRadius: '6px',
    overflow: 'hidden',
    marginBottom: '8px',
  },
  levelProgressFill: {
    height: '100%',
    width: '70%',
    background: 'white',
    borderRadius: '6px',
    transition: 'width 0.6s ease-out',
  },
  levelProgressText: {
    fontSize: '0.875rem',
    opacity: 0.9,
  },
  badgesGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '12px',
  },
  badgeCard: {
    position: 'relative',
    aspectRatio: '1',
    background: 'linear-gradient(135deg, #f8fafc, #ffffff)',
    borderRadius: '12px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    padding: '12px',
    border: '1px solid #e2e8f0',
    transition: 'all 0.3s',
    cursor: 'pointer',
  },
  badgeIcon: {
    fontSize: '2rem',
  },
  badgeName: {
    fontSize: '0.75rem',
    fontWeight: '600',
    color: '#64748b',
    textAlign: 'center',
  },
  unlockedIndicator: {
    position: 'absolute',
    top: '8px',
    right: '8px',
    width: '20px',
    height: '20px',
    borderRadius: '50%',
    background: '#10b981',
    color: 'white',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '0.75rem',
    fontWeight: '700',
  },
  activityList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  activityItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '12px',
    borderRadius: '8px',
    background: '#f8fafc',
    transition: 'background 0.2s',
    cursor: 'pointer',
  },
  activityIcon: {
    width: '36px',
    height: '36px',
    borderRadius: '8px',
    background: 'linear-gradient(135deg, #e0f2fe, #dbeafe)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#0c4a6e',
  },
  activityContent: {
    flex: 1,
  },
  activityAction: {
    fontSize: '0.875rem',
    fontWeight: '600',
    color: '#0c4a6e',
    marginBottom: '2px',
  },
  activityItemText: {
    fontSize: '0.875rem',
    color: '#64748b',
  },
  activityRight: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-end',
    gap: '2px',
  },
  activityPoints: {
    fontSize: '0.875rem',
    fontWeight: '700',
    color: '#10b981',
  },
  activityTime: {
    fontSize: '0.75rem',
    color: '#94a3b8',
  },
  // Notification styles
  notificationContainer: {
    position: 'fixed',
    top: '20px',
    right: '20px',
    zIndex: 1000,
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  notification: {
    padding: '16px 20px',
    borderRadius: '12px',
    boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
    animation: 'slideIn 0.3s ease-out',
    fontWeight: '600',
    fontSize: '0.875rem',
    maxWidth: '320px',
  },
  notificationsuccess: {
    background: 'linear-gradient(135deg, #10b981, #059669)',
    color: 'white',
  },
  notificationinfo: {
    background: 'linear-gradient(135deg, #3b82f6, #2563eb)',
    color: 'white',
  },
  notificationerror: {
    background: 'linear-gradient(135deg, #ef4444, #dc2626)',
    color: 'white',
  },
  // Modal styles
  modalOverlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    background: 'rgba(0, 0, 0, 0.6)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 999,
    backdropFilter: 'blur(4px)',
  },
  modal: {
    background: 'white',
    borderRadius: '24px',
    padding: '32px',
    maxWidth: '480px',
    width: '90%',
    boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
    animation: 'scaleIn 0.3s ease-out',
  },
  modalTitle: {
    fontSize: '1.5rem',
    fontWeight: '700',
    color: '#0c4a6e',
    marginBottom: '24px',
    textAlign: 'center',
  },
  sharePreview: {
    background: '#f8fafc',
    padding: '20px',
    borderRadius: '16px',
    marginBottom: '24px',
    position: 'relative',
  },
  shareButtons: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
    marginBottom: '16px',
  },
  shareBtn: {
    padding: '16px',
    borderRadius: '12px',
    border: 'none',
    color: 'white',
    fontSize: '1rem',
    fontWeight: '600',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '12px',
    transition: 'transform 0.2s',
    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
  },
  closeModalBtn: {
    width: '100%',
    padding: '12px',
    borderRadius: '12px',
    border: '2px solid #e2e8f0',
    background: 'white',
    color: '#64748b',
    fontSize: '0.875rem',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
  shareSmallBtn: {
    padding: '8px 12px',
    borderRadius: '8px',
    border: 'none',
    color: 'white',
    fontSize: '0.875rem',
    fontWeight: '600',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    transition: 'transform 0.2s',
  },

  // Recommendations styles
  recommendationsGrid: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  recommendationCard: {
    display: 'flex',
    gap: '16px',
    padding: '16px',
    background: 'linear-gradient(135deg, #f8fafc, #ffffff)',
    borderRadius: '12px',
    border: '1px solid #e2e8f0',
    transition: 'all 0.3s',
    cursor: 'pointer',
  },
  recImage: {
    width: '80px',
    height: '80px',
    borderRadius: '12px',
    background: 'linear-gradient(135deg, #e0f2fe, #dbeafe)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '2.5rem',
    flexShrink: 0,
  },
  recContent: {
    flex: 1,
  },
  recTitle: {
    fontSize: '1rem',
    fontWeight: '600',
    color: '#0c4a6e',
    marginBottom: '4px',
  },
  recReason: {
    fontSize: '0.75rem',
    color: '#64748b',
    marginBottom: '8px',
  },
  recPricing: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '12px',
  },
  recPrice: {
    fontSize: '1.25rem',
    fontWeight: '700',
    color: '#0c4a6e',
  },
  recDiscount: {
    padding: '4px 8px',
    background: '#dcfce7',
    color: '#166534',
    borderRadius: '6px',
    fontSize: '0.75rem',
    fontWeight: '600',
  },
  recFooter: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  confidenceBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    fontSize: '0.75rem',
    fontWeight: '600',
    color: '#92400e',
  },
  recViewBtn: {
    padding: '6px 16px',
    background: 'linear-gradient(135deg, #06b6d4, #3b82f6)',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    fontSize: '0.75rem',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  },

  // Social Stats styles
  socialStatsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '12px',
    marginBottom: '16px',
  },
  socialStatCard: {
    padding: '16px',
    background: 'linear-gradient(135deg, #f8fafc, #ffffff)',
    borderRadius: '12px',
    border: '1px solid #e2e8f0',
    textAlign: 'center',
  },
  socialStatIcon: {
    fontSize: '1.5rem',
    marginBottom: '8px',
  },
  socialStatValue: {
    fontSize: '1.5rem',
    fontWeight: '700',
    color: '#0c4a6e',
    marginBottom: '4px',
  },
  socialStatLabel: {
    fontSize: '0.75rem',
    color: '#64748b',
  },
  trendingTag: {
    padding: '12px',
    background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
    borderRadius: '12px',
    textAlign: 'center',
    fontSize: '0.875rem',
    fontWeight: '600',
    color: '#92400e',
  },

  // Restock Alerts styles
  restockList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  restockItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px',
    background: '#f8fafc',
    borderRadius: '12px',
    border: '1px solid #e2e8f0',
    gap: '12px',
  },
  restockInfo: {
    flex: 1,
  },
  restockProduct: {
    fontSize: '0.875rem',
    fontWeight: '600',
    color: '#0c4a6e',
    marginBottom: '4px',
  },
  restockZone: {
    fontSize: '0.75rem',
    color: '#64748b',
    marginBottom: '8px',
  },
  restockStatus: {
    display: 'inline-block',
    padding: '4px 10px',
    borderRadius: '6px',
    fontSize: '0.75rem',
    fontWeight: '600',
  },
  restockBtn: {
    padding: '8px 16px',
    background: 'linear-gradient(135deg, #06b6d4, #3b82f6)',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    fontSize: '0.75rem',
    fontWeight: '600',
    cursor: 'pointer',
    whiteSpace: 'nowrap',
    transition: 'transform 0.2s',
  },

  /* ---------------- Coupons specific styles ---------------- */
  couponsHeader: {
    background: 'white',
    borderRadius: '20px',
    padding: '32px',
    marginBottom: '24px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.06)',
    border: '1px solid rgba(226, 232, 240, 0.8)',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '16px',
  },
  backBtn: {
    padding: '12px 20px',
    borderRadius: '12px',
    border: '2px solid #e2e8f0',
    background: 'white',
    color: '#64748b',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
  couponsTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    fontSize: '1.75rem',
    fontWeight: '700',
    color: '#0c4a6e',
  },
  pointsDisplay: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '12px 24px',
    background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
    borderRadius: '12px',
  },
  pointsValue: {
    fontSize: '1.5rem',
    fontWeight: '700',
    color: '#92400e',
  },
  pointsLabel: {
    fontSize: '0.875rem',
    color: '#92400e',
    fontWeight: '600',
  },
  couponsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: '20px',
  },
  couponCard: {
    position: 'relative',
    padding: '24px',
    borderRadius: '16px',
    background: 'white',
    border: '3px solid',
    boxShadow: '0 8px 24px rgba(0, 0, 0, 0.08)',
    transition: 'transform 0.3s, box-shadow 0.3s',
    cursor: 'pointer',
    textAlign: 'center',
  },
  ownedCouponCard: {
    position: 'relative',
    padding: '24px',
    borderRadius: '16px',
    background: 'white',
    border: '3px solid',
    boxShadow: '0 8px 24px rgba(0, 0, 0, 0.08)',
    transition: 'transform 0.3s, box-shadow 0.3s',
    cursor: 'pointer',
    textAlign: 'center',
  },
  ownedBadge: {
    position: 'absolute',
    top: '12px',
    right: '12px',
    background: '#10b981',
    color: 'white',
    padding: '6px 12px',
    borderRadius: '8px',
    fontSize: '0.75rem',
    fontWeight: '700',
  },
  ownedOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    background: 'rgba(16, 185, 129, 0.9)',
    borderRadius: '13px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    color: 'white',
    fontSize: '1.25rem',
    fontWeight: '700',
  },
  rarityBadge: {
    display: 'inline-block',
    padding: '6px 12px',
    borderRadius: '8px',
    color: 'white',
    fontSize: '0.75rem',
    fontWeight: '700',
    marginBottom: '12px',
    textTransform: 'uppercase',
  },
  couponIcon: {
    fontSize: '3.5rem',
    marginBottom: '12px',
  },
  couponName: {
    fontSize: '1.125rem',
    fontWeight: '700',
    color: '#0c4a6e',
    marginBottom: '8px',
  },
  couponDiscount: {
    fontSize: '2rem',
    fontWeight: '700',
    color: '#10b981',
    marginBottom: '8px',
  },
  couponCategory: {
    fontSize: '0.875rem',
    color: '#64748b',
    marginBottom: '16px',
  },
  couponCost: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    marginBottom: '16px',
    fontSize: '1rem',
    fontWeight: '700',
    color: '#92400e',
  },
  purchaseBtn: {
    width: '100%',
    padding: '12px',
    borderRadius: '12px',
    border: 'none',
    fontWeight: '600',
    fontSize: '0.875rem',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    transition: 'transform 0.2s',
  },
  useCouponBtn: {
    width: '100%',
    padding: '12px',
    borderRadius: '12px',
    border: 'none',
    color: 'white',
    fontWeight: '600',
    fontSize: '0.875rem',
    cursor: 'pointer',
    transition: 'transform 0.2s',
    marginTop: '12px',
  },
  costDisplay: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '12px',
    padding: '20px',
    background: '#f8fafc',
    borderRadius: '12px',
    marginTop: '16px',
  },

  // modal buttons reused for coupons
  modalBtn: {
    flex: 1,
    padding: '14px',
    borderRadius: '12px',
    border: 'none',
    color: 'white',
    fontSize: '1rem',
    fontWeight: '600',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    transition: 'transform 0.2s',
  },
};

/* ---------- Add keyframes / small global CSS rules (appended to document.head) ---------- */
const styleSheet = document.createElement('style');
styleSheet.textContent = `
  @keyframes slideUp {
    from { opacity: 0; transform: translateY(20px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes slideIn {
    from { opacity: 0; transform: translateX(100px); }
    to { opacity: 1; transform: translateX(0); }
  }
  @keyframes scaleIn {
    from { opacity: 0; transform: scale(0.9); }
    to { opacity: 1; transform: scale(1); }
  }

  .statCard:hover { transform: translateY(-4px); box-shadow: 0 8px 24px rgba(0,0,0,0.12) !important; }
  .challengeCard:hover, .offerCard:hover, .recommendationCard:hover, .couponCard:hover { transform: translateY(-4px); box-shadow: 0 12px 32px rgba(0,0,0,0.12) !important; }
  .shareBtn:hover, .recViewBtn:hover, .restockBtn:hover, .purchaseBtn:hover { transform: scale(1.03); }
  .closeModalBtn:hover { background: #f8fafc; border-color: #cbd5e1; }
  .notificationBtn:hover { transform: scale(1.1); }
  .viewAllBtn:hover { transform: translateX(4px); }

  @media (max-width: 1200px) {
    .mainContent { grid-template-columns: 1fr !important; }
  }
  @media (max-width: 640px) {
    .statsGrid { grid-template-columns: repeat(2, 1fr) !important; }
    .offersGrid { grid-template-columns: 1fr !important; }
    .badgesGrid { grid-template-columns: repeat(2, 1fr) !important; }
    .socialStatsGrid { grid-template-columns: 1fr !important; }
    .couponsGrid { grid-template-columns: 1fr !important; }
  }
`;
document.head.appendChild(styleSheet);

export default Dashboard;