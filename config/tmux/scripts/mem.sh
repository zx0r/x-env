#!/usr/bin/env bash

# macOS Apple Silicon
vm_stat | awk '
/Mach Virtual Memory Statistics/ { ps=$8 }
/Pages active/ { a=$3 }
/Pages wired/ { w=$4 }
/Pages occupied by compressor/ { c=$5 }
/Pages free/ { f=$3 }
/Pages inactive/ { i=$3 }
/Pages speculative/ { s=$3 }
END {
  gsub("\\.","",a); gsub("\\.","",w); gsub("\\.","",c);
  gsub("\\.","",f); gsub("\\.","",i); gsub("\\.","",s);

  total = (a+w+c+f+i+s)
  used  = (a+w+c)

  pct = int(used * 100 / total)

  if (pct >= 80)
    color="#[fg=#ff0000,bg=default]"
  else if (pct >= 70)
    color="#[fg=#ffff00,bg=default]"
  else
    color="#[fg=#00ff00,bg=default]"

  printf "%s %d%%\n", color, pct
}'

# Gentoo Linux
# Define color codes for memory usage levels in tmux status bar
# COLOR_MEM_LOW="#[fg=#00ff00, bg=default]"
# COLOR_MEM_MODERATE="#[fg=#ffff00, bg=default]"
# COLOR_MEM_HIGH="#[fg=#ff0000, bg=default]"

# # Calculate memory usage percentage
# mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')

# # Display memory usage with color coding based on thresholds
# if ((mem_usage >= 80)); then
#   echo "${COLOR_MEM_HIGH} ${mem_usage}%"
# elif ((mem_usage >= 60)); then
#   echo "${COLOR_MEM_MODERATE} ${mem_usage}%"
# elif ((mem_usage >= 40)); then
#   echo "${COLOR_MEM_MODERATE} ${mem_usage}%"
# elif ((mem_usage >= 20)); then
#   echo "${COLOR_MEM_LOW} ${mem_usage}%"
# else
#   echo "${COLOR_MEM_LOW} ${mem_usage}%"
# fi
