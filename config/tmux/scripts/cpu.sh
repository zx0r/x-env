#!/usr/bin/env bash

# CPU benchmark on macOS Apple Silicon
cores=$(sysctl -n hw.ncpu)

ps -A -o %cpu | awk -v c="$cores" '
NR>1 { total += $1 }
END {
  pct=int(total/c)

  if (pct >= 80)
    color="#[fg=#ff0000,bg=default]"
  else if (pct >= 50)
    color="#[fg=#ffff00,bg=default]"
  else
    color="#[fg=#00ff00,bg=default]"

  printf "%s󰍛 %d%%\n", color, pct
}'

# Gentoo Linux 
# COLOR_CPU_LOW="#[fg=#00ff00, bg=default]"
# COLOR_CPU_MODERATE="#[fg=#ffff00, bg=default]"
# COLOR_CPU_HIGH="#[fg=#ff0000, bg=default]"

# # Get current CPU usage
# cpu_usage_total=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# # Display CPU usage with color coding based on thresholds
# if (($(echo "$cpu_usage_total >= 80" | bc -l))); then
#   echo "${COLOR_CPU_HIGH} ${cpu_usage_total}%"
# elif (($(echo "$cpu_usage_total >= 60" | bc -l))); then
#   echo "${COLOR_CPU_MODERATE} ${cpu_usage_total}%"
# elif (($(echo "$cpu_usage_total >= 40" | bc -l))); then
#   echo "${COLOR_CPU_MODERATE} ${cpu_usage_total}%"
# elif (($(echo "$cpu_usage_total >= 20" | bc -l))); then
#   echo "${COLOR_CPU_LOW} ${cpu_usage_total}%"
# else
#   echo "${COLOR_CPU_LOW} ${cpu_usage_total}%"
# fi
