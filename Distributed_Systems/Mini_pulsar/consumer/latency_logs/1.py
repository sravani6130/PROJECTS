import pandas as pd
import matplotlib.pyplot as plt

# Read the CSV with no header
df = pd.read_csv("latency_log_demo.csv", header=None, names=["message_id", "receive_time_utc", "latency_str"])

# Create line number-based index (0-based, so add +1 if needed)
df["msg_index"] = df.index + 1

# Convert latency like "6.37s" to float milliseconds
df["latency_ms"] = df["latency_str"].str.replace('ms', '', regex=False).astype(float) * 1000

# Plotting
plt.figure(figsize=(12, 5))
plt.plot(df["msg_index"], df["latency_ms"], marker='o', linestyle='-', color='blue')
plt.title("Latency per Message (Line Number Based)")
plt.xlabel("Message Number (Line Number)")
plt.ylabel("Latency (ms)")
plt.grid(True)
plt.tight_layout()
plt.show()
