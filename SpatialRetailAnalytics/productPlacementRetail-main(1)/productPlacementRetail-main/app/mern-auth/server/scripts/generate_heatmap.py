import cv2
import base64
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.stats import gaussian_kde
from scipy.ndimage import gaussian_filter
from io import BytesIO

# -------------------------------------------
#  Read files directly from folder
# -------------------------------------------
layout_path = "/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/mern-auth/server/uploads/layout_straight.png"
arr_path = "/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/mern-auth/server/uploads/arrangement_straight.csv"
tx_path = "/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/mern-auth/server/uploads/transactions_straight.csv"

# ---- Load layout image ----
layout = cv2.imread(layout_path)
layout = cv2.cvtColor(layout, cv2.COLOR_BGR2RGB)
h, w, _ = layout.shape

# ---- Load CSVs ----
arr = pd.read_csv(arr_path)   # contains item_id, x, y
tx = pd.read_csv(tx_path)     # contains item_id, quantity, price

tx["revenue"] = tx["quantity"] * tx["price"]

df = arr.merge(
    tx.groupby("item_id")["revenue"].sum().reset_index(),
    on="item_id",
    how="left"
)
df["revenue"] = df["revenue"].fillna(0)

x = df["x"].values
y = df["y"].values
weights = df["revenue"].values

# KDE grid
xx, yy = np.mgrid[0:w:400j, 0:h:400j]
positions = np.vstack([xx.ravel(), yy.ravel()])
xy = np.vstack([x, y])

kde = gaussian_kde(xy, weights=weights)
density = kde(positions).reshape(xx.shape)
density = gaussian_filter(density, sigma=25)

density_norm = (density - density.min()) / (density.max() - density.min() + 1e-9)

# ---- Plot heatmap ----
fig, ax = plt.subplots(figsize=(12, 8))
ax.imshow(layout)
ax.imshow(
    density_norm.T,
    cmap="jet",
    alpha=0.55,
    extent=[0, w, h, 0],
    interpolation="bicubic"
)
ax.axis("off")

# --------------------------------------
#  SAVE HEATMAP ON SERVER
# --------------------------------------
SAVE_PATH = "/home/user/Desktop/BTP/productPlacementRetail-main(1)/productPlacementRetail-main/app/mern-auth/server/uploads/generated_heatmap.png"

plt.savefig(SAVE_PATH, format="png", bbox_inches="tight", pad_inches=0)

# --------------------------------------
#  Also return Base64 to frontend
# --------------------------------------
buf = BytesIO()
plt.savefig(buf, format="png", bbox_inches="tight", pad_inches=0)
buf.seek(0)
img_base64 = base64.b64encode(buf.read()).decode("utf-8")

print("data:image/png;base64," + img_base64)
