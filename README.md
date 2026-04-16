# 📡 Wi-Fi-Based Indoor Positioning System (IEEE 802.11az)

## 📌 Overview
This project focuses on **Wi-Fi-based indoor positioning** using IEEE 802.11az principles. The goal is to achieve accurate **3D localization** by leveraging wireless channel characteristics such as:

- Channel Impulse Response (CIR)
- Time of Flight (ToF)
- Angle of Arrival (AoA)
- Received Signal Strength Indicator (RSSI)

The system integrates **machine learning (CNN-based models)** and **optimization techniques (Genetic Algorithm)** for improved positioning accuracy.

---

## 🚀 Key Features

- 📊 **CIR-based feature extraction** from simulated wireless channels  
- 🧠 **Deep Learning (CNN / ResNet)** for classification & regression  
- 📍 **3D indoor localization (x, y, z prediction)**  
- 📡 **Access Point (AP) placement optimization** using Genetic Algorithm  
- 📈 Performance evaluation using:
  - Accuracy
  - CDF plots
  - Confusion Matrix  
- 🏗️ Support for custom indoor environments (.stl models)

---

## 🧠 Methodology

### 1. Data Generation
- Ray tracing simulation of indoor environment
- Extraction of CIR and other RF features

### 2. Feature Engineering
- Normalization of CIR data
- Multi-feature fusion (CIR + RSSI + ToA + AoA)

### 3. Model Training
- CNN-based architecture
- Hybrid model:
  - Classification → Zone prediction
  - Regression → Exact position (x, y, z)

### 4. Optimization
- Genetic Algorithm used to:
  - Optimize AP placement
  - Minimize path loss
  - Improve coverage

### 5. Evaluation
- Localization error (CDF)
- Classification accuracy
- Robustness under noise

---

## ⚙️ Requirements

- MATLAB (with Deep Learning Toolbox)
- Python (optional for preprocessing / extensions)
- Git

---

## 🛠️ Setup

```bash
git clone https://github.com/your-username/Wi-Fi-based-positioning.git
cd Wi-Fi-based-positioning

⚠️ Important Note (Large File Handling)

A large .stl file was removed from the repository history to comply with GitHub file size limits.

If needed:

Store large files using Git LFS or external storage
Avoid committing files >100 MB
```

📊 Results (Example)
- Improved localization accuracy using hybrid CNN model
- Optimized AP placement reduces positioning error
- Robust performance under varying SNR conditions

📌 Future Work
- Real-world dataset validation
- Integration with ROS2 / robotic systems
- Deployment on embedded platforms
- Fusion with SLAM systems

👩‍💻 Author
- Kavya Dave 
- Master’s Student – TUHH
- Wireless Localization | Deep learning | MATLAB

📄 License
- This project is for academic and research purposes.

