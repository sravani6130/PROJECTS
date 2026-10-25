import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

# Load producer send times
send_df = pd.read_csv("producer_log.csv", parse_dates=["send_time_utc"])

# Plot send times
plt.figure(figsize=(12, 5))
plt.plot(send_df["send_time_utc"], range(len(send_df)), marker='o', linestyle='-', color='green')
plt.title("Producer Message Send Timeline")
plt.xlabel("Send Time (UTC)")
plt.ylabel("Message Sequence Number")
plt.grid(True)
plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()
