import networkx as nx
import itertools
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np
import pandas as pd
# ---------------------------------------
# Supermarket Layout Parameters
# ---------------------------------------
rack_count = 6
slots_per_rack = 6
slot_gap = 10
rack_gap = 10
ITEM_LOCATION_MAP = {
    "Apples": "R1S1",
    "Bananas": "R1S2",
    "Grapes": "R1S3",
    "Oranges": "R1S4",
    "Pineapple": "R1S5",
    "Watermelon": "R1S6",
    "Chips": "R2S1",
    "Cookies": "R2S2",
    "Namkeen": "R2S3",
    "Popcorn": "R2S4",
    "Nuts": "R2S5",
    "Milk": "R3S1",
    "Butter": "R3S2",
    "Cheese": "R3S3",
    "Bread": "R3S4",
    "Yogurt": "R3S5",
    "Cakes": "R3S6",
    "Tea": "R4S1",
    "Coffe": "R4S2",
    "Soda": "R4S3",
    "Juice": "R4S4",
    "EnergyDrink": "R4S5",
    "Milkshake": "R4S6",
    "Detergent": "R5S1",
    "Soap": "R5S2",
    "Sponges": "R5S3",
    "Bleach": "R5S4",
    "Floor Cleaner": "R5S5",
    "Toilet Cleaner": "R5S6",
    "Ice Cream": "R6S1",
    "SeaFood": "R6S2",
    "Peas": "R6S3",
    "French Fries": "R6S4",
    "Chicken Nuggets": "R6S5"
    

}
csv_path = "final_list.csv"

# Load CSV with NO HEADER
df = pd.read_csv(csv_path, header=None, names=["Item"])

# ---------------------------------------
# Create Graph with Weighted Edges
# ---------------------------------------
G = nx.Graph()

# Vertical aisles (Between Racks 1-4)
for r in range(1, 5):
    for s in range(1, slots_per_rack):
        G.add_edge(f"R{r}S{s}", f"R{r}S{s+1}", weight=slot_gap)

# Horizontal aisle (Rack 5)
for s in range(1, slots_per_rack):
    G.add_edge(f"R6S{s}", f"R6S{s+1}", weight=slot_gap)

# Cross-aisle connections (top & bottom)
for s in [1, 6]:
    for r in range(1, 5):
        G.add_edge(f"R{r}S{s}", f"R{r+1}S{s}", weight=rack_gap)

# Connections to horizontal rack
G.add_edge("R1S6", "R6S1", weight=10)
G.add_edge("R2S6", "R6S2", weight=10)
G.add_edge("R3S6", "R6S3", weight=10)
G.add_edge("R4S6", "R6S4", weight=10)
G.add_edge("R5S6", "R6S5", weight=10)

# ---------------------------------------
# Coordinate System - Walking paths between shelves
# ---------------------------------------
coords = {}
shelf_width = 4
aisle_width = 6

# For vertical racks: walking path is BETWEEN consecutive shelves
# R1 aisle is between shelf 0 and shelf 1
# R2 aisle is between shelf 1 and shelf 2
# R3 aisle is between shelf 2 and shelf 3
# R4 aisle is between shelf 3 and shelf 4

for r in range(1, 6):
    # Aisle r is between shelf (r-1) and shelf r
    x = (r - 1) * (shelf_width + aisle_width) + shelf_width + aisle_width/2
    for s in range(1, slots_per_rack + 1):
        y = s * slot_gap
        coords[f"R{r}S{s}"] = (x, y)

# Horizontal aisle (R5)
base_y = 70
for s in range(1, slots_per_rack + 1):
    x = (s - 1) * slot_gap
    coords[f"R6S{s}"] = (x, base_y)

# ---------------------------------------
# Shopping List (Selected Items)
# ---------------------------------------
shopping_list = []
item_labels = {}

for item in df["Item"]:
    if item not in ITEM_LOCATION_MAP:
        print(f"❌ MISSING MAPPING → '{item}' (Add it to ITEM_LOCATION_MAP)")
        continue

    rack_slot = ITEM_LOCATION_MAP[item]
    shopping_list.append(rack_slot)
    item_labels[rack_slot] = item

# ---------------------------------------
# TSP Solver: Find Shortest Path
# ---------------------------------------
distances = {}
for a, b in itertools.combinations(shopping_list, 2):
    d = nx.shortest_path_length(G, a, b, weight="weight")
    distances[(a, b)] = d
    distances[(b, a)] = d

best_order, best_cost = None, float("inf")
for perm in itertools.permutations(shopping_list):
    cost = sum(distances[(perm[i], perm[i + 1])] for i in range(len(perm) - 1))
    if cost < best_cost:
        best_cost, best_order = cost, perm

# Build complete path
full_path = []
for i in range(len(best_order) - 1):
    segment = nx.shortest_path(G, best_order[i], best_order[i + 1], weight="weight")
    full_path += segment[:-1]
full_path.append(best_order[-1])

# ---------------------------------------
# Create Professional Visualization
# ---------------------------------------
fig, ax = plt.subplots(figsize=(16, 11))
fig.patch.set_facecolor('#f8f9fa')
ax.set_facecolor('#f5f5f5')

shelf_color = '#2c3e50'
y_start, y_end = slot_gap, slot_gap * slots_per_rack

# Draw 4 VERTICAL SHELVES (not 8!)
# Shelves are numbered 0, 1, 2, 3, 4 from left to right
for shelf_num in range(5):
    x_pos = shelf_num * (shelf_width + aisle_width)
    
    ax.add_patch(Rectangle((x_pos, y_start), 
                           shelf_width, y_end - y_start,
                           facecolor=shelf_color, edgecolor='#1a252f', 
                           linewidth=2, zorder=2))
    
    # Label shelves
    ax.text(x_pos + shelf_width/2, y_start - 3, f'SHELF\n{shelf_num+1}', 
            fontsize=10, weight='bold', ha='center', va='top',
            color=shelf_color)

# Draw 4 AISLES between the 5 shelves
for aisle_num in range(1, 5):
    # Aisle between shelf (aisle_num-1) and shelf (aisle_num)
    x_start_aisle = (aisle_num - 1) * (shelf_width + aisle_width) + shelf_width
    
    # Draw aisle background (white walking area)
    ax.add_patch(Rectangle((x_start_aisle, y_start), 
                           aisle_width, y_end - y_start,
                           facecolor='white', edgecolor='#bdc3c7',
                           linewidth=1, alpha=0.9, zorder=1))
    
    # Add aisle label at top
    ax.text(x_start_aisle + aisle_width/2, y_end + 2, 
            f'AISLE {aisle_num}', fontsize=13, weight='bold', 
            ha='center', color='#e74c3c',
            bbox=dict(boxstyle='round,pad=0.5', facecolor='white', 
                     edgecolor='#e74c3c', linewidth=2))

# Draw horizontal shelves for aisle 5
x_start_h = 0
x_end_h = coords[f"R5S{slots_per_rack}"][0]+3



# Bottom shelf  
ax.add_patch(Rectangle((x_start_h, base_y + aisle_width/2), 
                       x_end_h - x_start_h, shelf_width,
                       facecolor=shelf_color, edgecolor='#1a252f', 
                       linewidth=2, zorder=2))

# Horizontal aisle background
ax.add_patch(Rectangle((x_start_h, base_y - aisle_width/2), 
                       x_end_h - x_start_h, aisle_width,
                       facecolor='white', edgecolor='#bdc3c7',
                       linewidth=1, alpha=0.9, zorder=1))

ax.text(-5, base_y, 'AISLE 5', fontsize=13, weight='bold', 
        va='center', ha='right', color='#e74c3c',
        bbox=dict(boxstyle='round,pad=0.5', facecolor='white', 
                 edgecolor='#e74c3c', linewidth=2))

# Draw all possible paths (light gray dashed lines)
for u, v in G.edges():
    x1, y1 = coords[u]
    x2, y2 = coords[v]
    ax.plot([x1, x2], [y1, y2], color='#bdc3c7', linewidth=1.5, 
            alpha=0.3, linestyle='--', zorder=3)

# Draw optimal shopping path (RED - in the aisles)
path_x = [coords[n][0] for n in full_path]
path_y = [coords[n][1] for n in full_path]


# Add directional arrows
for i in range(0, len(path_x)-1, max(1, len(path_x)//6)):
    dx = path_x[i+1] - path_x[i]
    dy = path_y[i+1] - path_y[i]
    if dx != 0 or dy != 0:
        ax.annotate('', xy=(path_x[i+1], path_y[i+1]), 
                    xytext=(path_x[i], path_y[i]),
                    arrowprops=dict(arrowstyle='->', color='#c0392b', 
                                  lw=3.5, alpha=0.9), zorder=6)



for idx, item in enumerate(shopping_list):
    x, y = coords[item]
    
    # Draw item marker
    ax.scatter(x, y, color='#f39c12', s=450, zorder=7, 
              edgecolors='white', linewidths=3)
    ax.scatter(x, y, color='#f39c12', s=220, zorder=8, alpha=0.9)
    
    # Add item number
    ax.text(x, y, str(idx+1), fontsize=13, weight='bold', 
           ha='center', va='center', color='white', zorder=9)
    
    # Add item label with pointer
    label = item_labels.get(item, item)
    offset_x = 4 if idx % 2 == 0 else -4
    offset_y = 2.5
    ax.annotate(label, xy=(x, y), xytext=(x + offset_x, y + offset_y),
               fontsize=12, weight='bold', color='white',
               bbox=dict(boxstyle='round,pad=0.6', facecolor='#e67e22', 
                        edgecolor='white', linewidth=2.5, alpha=0.95),
               arrowprops=dict(arrowstyle='->', color='#e67e22', lw=2.5),
               zorder=10)

# Add start marker
start_x, start_y = coords[best_order[0]]
ax.scatter(start_x, start_y, marker='*', s=900, color='#27ae60', 
          zorder=11, edgecolors='white', linewidths=3, label='START')
ax.text(start_x, start_y - 3, 'START', fontsize=11, weight='bold',
       ha='center', color='#27ae60',
       bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.8))

# Add end marker
end_x, end_y = coords[best_order[-1]]
ax.scatter(end_x, end_y, marker='s', s=450, color='#2980b9', 
          zorder=11, edgecolors='white', linewidths=3, label='FINISH')
ax.text(end_x, end_y - 3, 'FINISH', fontsize=11, weight='bold',
       ha='center', color='#2980b9',
       bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.8))



# Legend
legend = ax.legend(loc='upper right', fontsize=11, frameon=True, 
                  shadow=True, fancybox=True)
legend.get_frame().set_facecolor('#ffffff')
legend.get_frame().set_alpha(0.95)

# Grid
ax.grid(True, alpha=0.15, linestyle=':', linewidth=0.5, color='#7f8c8d')
ax.set_aspect('equal')
plt.tight_layout()

# Add info box
info_text = f"SHOPPING LIST:\n"
info_text += "─" * 28 + "\n"
for idx, item in enumerate(best_order):
    label = item_labels.get(item, item)
    info_text += f"{idx+1}. {label} ({item})\n"
info_text += "─" * 28 + "\n"
info_text += f"Total Distance: {best_cost:.1f}m"

# Smaller info box
fig.text(0.01, 0.98, info_text,
         fontsize=7,
         va='top', ha='left',
         bbox=dict(boxstyle='round,pad=0.35',
                   facecolor='white', alpha=0.90,
                   edgecolor='#34495e', linewidth=1),
         family='monospace', weight='bold')


# Add legend explanation
legend_text = "🔲 Dark = Shelves (6 total)\n⚪ White = Aisles (5 walking paths)\n🔴 Red = Your optimal route"
# Smaller legend box
fig.text(0.99, 0.02, legend_text,
         fontsize=7,
         va='bottom', ha='right',
         bbox=dict(boxstyle='round,pad=0.30',
                   facecolor='#ecf0f1', alpha=0.85,
                   edgecolor='#95a5a6', linewidth=1),
         style='italic')
plt.tight_layout()
output_path = "shopping_path.png"
plt.savefig(output_path, dpi=300, bbox_inches="tight")
print("IMAGE_SAVED:", output_path)
#plt.show()

# ---------------------------------------
# Print Results
# ---------------------------------------
print("="*60)
print("     SUPERMARKET SHOPPING PATH OPTIMIZATION")
print("="*60)
print(f"\nStore Layout:")
print(f"  • 5 Vertical Shelves")
print(f"  • 4 Aisles (walking paths between shelves)")
print(f"  • 1 Horizontal aisle (Aisle 5)")
print(f"\n✓ Optimal Shopping Order:")
for idx, item in enumerate(best_order, 1):
    label = item_labels.get(item, item)
    print(f"   {idx}. {label:15s} → Location: {item}")

print(f"\n✓ Total Walking Distance: {best_cost:.1f} meters")
print(f"✓ Number of Items: {len(shopping_list)}")
print(f"✓ Algorithm: Traveling Salesman Problem (TSP)")
print(f"\n📍 The red path ONLY travels through WHITE AISLES")
print(f"📍 Dark boxes = SHELVES (products picked from sides)")
print("\nDetailed Path Sequence:")
print("   " + " → ".join(full_path))
print("="*60)
