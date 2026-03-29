import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import gaussian_kde
import cv2
from scipy.ndimage import gaussian_filter

# ----------------------------------------
# Load store layout blueprint
# ----------------------------------------
layout = cv2.imread("/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/layout_straight.png")
layout = cv2.cvtColor(layout, cv2.COLOR_BGR2RGB)
h, w, _ = layout.shape

# ----------------------------------------
# Load arrangement + transaction data
# ----------------------------------------
arr = pd.read_csv("/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/arrangement_straight.csv")
tx = pd.read_csv("/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/transactions_straight.csv")
tx['revenue'] = tx['quantity'] * tx['price']

df = arr.merge(tx.groupby("item_id")['revenue'].sum().reset_index(),
               on="item_id", how="left")
df['revenue'] = df['revenue'].fillna(0)

x = df['x'].values
y = df['y'].values
weights = df['revenue'].values

# ----------------------------------------
# High-resolution KDE grid (4× larger)
# ----------------------------------------
grid_x = 4 * w
grid_y = 4 * h

xx, yy = np.mgrid[0:w:grid_x*1j, 0:h:grid_y*1j]

positions = np.vstack([xx.ravel(), yy.ravel()])
xy = np.vstack([x, y])

kde = gaussian_kde(xy, weights=weights)
density = kde(positions).reshape(xx.shape)

# Smooth the KDE map to make it like real store heatmap
density = gaussian_filter(density, sigma=35)

# Normalize 0–1
density_norm = (density - density.min()) / (density.max() - density.min())

# ----------------------------------------
# Plot on layout
# ----------------------------------------
plt.figure(figsize=(12, 8))

plt.imshow(layout)

plt.imshow(
    density_norm.T,
    cmap="jet",
    alpha=0.55,
    extent=[0, w, h, 0],
    interpolation="bicubic"
)

plt.axis("off")
plt.title("Store Revenue Heatmap (Smooth Like Real Map)")
plt.show()
