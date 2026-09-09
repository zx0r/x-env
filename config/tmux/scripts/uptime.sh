#!/usr/bin/env bash

# macOS Version
uptime | awk -F'[ ,:\t\n]+' '{
    msg = " "
    if ($5 == "day" || $5 == "days") {
        # If uptime includes days, extract days and time
        msg = msg $4 $5 " "
        n = $6  # Hours
        o = $7  # Minutes
    } else {
        # If uptime is less than a day, extract hours and minutes
        n = $4  # Hours
        o = $5  # Minutes
    }

    # Format the hours and minutes
    if (int(o) == 0) {
        msg = msg int(n)" "o
    } else {
        msg = msg int(n) "h "
        msg = msg int(o) "m"
    }

    print msg
}'

# Gentoo Linux Version
# uptime | awk -F'[ ,:\t\n]+' '{
#       msg = " "
#       if ($7 == "day" || $7 == "days") {
#         msg = msg $6 $7 " "
#         n = $8
#         o = $9
#       } else {
#         n = $6
#         o = $7
#       }

#       if (int(o) == 0) {
#         msg = msg int(n)" "o
#       } else {
#         msg = msg int(n) "h "
#         msg = msg int(o) "m"
#       }

#       print msg
#     }'
