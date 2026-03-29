import React from 'react'
import { Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import Login from './pages/Login'
import Signup from "./pages/SignUp";
import Dashboard from './pages/Dashboard';
import Features from './pages/Features';
import Pricing from './pages/Pricing';
import Heatmap from './pages/Heatmap';


const App = () => {
  return (
    <div className='text-2xl'>
      <Routes> 
        <Route path='/' element={<Home />} />
        <Route path='/login' element={<Login />} />
        <Route path="/register" element={<Signup />} /> 
        <Route path="/dashboard" element={<Dashboard />} /> 
        <Route path='/features' element={<Features />} />
        <Route path='/pricing' element={<Pricing />} />
        <Route path='/heatmap' element={<Heatmap />} />
    
      </Routes>
    </div>
  )
}

export default App
