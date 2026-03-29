import React from "react";
import { Routes, Route } from "react-router-dom";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Signup from "./pages/Signup";
import Dashboard from "./pages/Dashboard";
import Features from "./pages/Features";
import AisleNavigator from "./pages/AisleNavigator";
import Header from "./components/Header";
import FruitsPage from "./pages/FruitsPage";
import SnacksPage from "./pages/SnacksPage";
import DairyPage from "./pages/DairyPage";
import BeveragesPage from "./pages/BeveragesPage";
import CleaningPage from "./pages/CleaningPage";
import FrozenPage from "./pages/FrozenPage";
import VisualPage from "./pages/VisualPage";
const App = () => {
  return (
    <>
      <Header />
      <div className="text-2xl">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Signup />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/features" element={<Features />} />
          <Route path="/aislenavigator" element={<AisleNavigator />} />
          <Route path="/fruits" element={<FruitsPage />} />
          <Route path="/aisles" element={<AisleNavigator />} />
          <Route path="/snacks" element={<SnacksPage />} />
          <Route path="/dairy" element={<DairyPage />} />
          <Route path="/beverages" element={<BeveragesPage />} />
          <Route path="/cleaning" element={<CleaningPage />} />
          <Route path="/frozen" element={<FrozenPage />} />
<Route path="/visual" element={<VisualPage />} />
          {/* Fallback for invalid routes */}
          <Route path="*" element={<div>404 Not Found</div>} />
        </Routes>
      </div>
    </>
  );
};

export default App;