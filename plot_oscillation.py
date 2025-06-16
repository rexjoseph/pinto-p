import pandas as pd
import matplotlib.pyplot as plt

# Read the CSV file
df = pd.read_csv('oscillation_data.csv')

# Convert temperature from raw value to percentage (divide by 1e6)
df['prev_temp'] = df['prev_temp'] / 1e6

# Create figure and axis objects with a single subplot
fig, ax1 = plt.subplots(figsize=(15, 8))

# Plot cultivation factor on primary y-axis
color1 = 'tab:blue'
ax1.set_xlabel('Season')
ax1.set_ylabel('Cultivation Factor', color=color1)
line1 = ax1.plot(df['season'], df['cultivation_factor'], color=color1, label='Cultivation Factor')
ax1.tick_params(axis='y', labelcolor=color1)

# Create second y-axis for temperature
ax2 = ax1.twinx()
color2 = 'tab:red'
ax2.set_ylabel('Temperature (%)', color=color2)
line2 = ax2.plot(df['season'], df['prev_temp'], color=color2, label='Temperature')
ax2.tick_params(axis='y', labelcolor=color2)

# Add vertical lines to separate different steps
step_changes = df[df['step'] != df['step'].shift()].index
for idx in step_changes:
    ax1.axvline(x=df['season'].iloc[idx], color='gray', linestyle='--', alpha=0.3)

# Add step labels
for idx in step_changes:
    step_name = df['step'].iloc[idx]
    ax1.text(df['season'].iloc[idx], ax1.get_ylim()[0], step_name, 
             rotation=45, ha='right', va='top')

# Add title
plt.title('Oscillation Data: Cultivation Factor and Temperature')

# Add legend
lines = line1 + line2
labels = [l.get_label() for l in lines]
ax1.legend(lines, labels, loc='upper left')

# Adjust layout to prevent label cutoff
plt.tight_layout()

# Save the plot
plt.savefig('oscillation_plot.png')
plt.close() 