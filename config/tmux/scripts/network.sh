#!/usr/bin/env bash

readonly GREEN="#[fg=green,bold]"
readonly RED="#[fg=red,bold]"
readonly RESET="#[fg=default]"

readonly DNS_PORT=53
readonly TOR_PORT=9050
readonly VPN_GATEWAY=10.64.0.1

dns() {
	if nc -z -u -w1 127.0.0.1 "$DNS_PORT" >/dev/null 2>&1; then
		printf "%sDNSCRYPT%s" "$GREEN" "$RESET"
	else
		printf "%sDNS-DOWN%s" "$RED" "$RESET"
	fi
}

vpn() {
	if ifconfig | grep -q utun &&
		ping -c1 -t1 "$VPN_GATEWAY" >/dev/null 2>&1; then
		printf "%sVPN%s" "$GREEN" "$RESET"
	else
		printf "%sVPN%s" "$RED" "$RESET"
	fi
}

tor() {
	if nc -z -w1 127.0.0.1 "$TOR_PORT" >/dev/null 2>&1; then
		printf "%sTOR%s" "$GREEN" "$RESET"
	else
		printf "%sTOR%s" "$RED" "$RESET"
	fi
}

leaks() {
	local ip count

	ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
	count=$(sudo lsof -i -nP -itcp | grep "$ip" | grep ESTABLISHED | grep -v 127.0.0.1 | wc -l | xargs)

	if [[ -z $ip ]]; then
		printf "%sOFFLINE%s" "$RED" "$RESET"
		return
	fi

	if ((count == 0)); then
		printf "%sLEAK%s" "$GREEN" "$RESET"
	else
		printf "%sLEAK:%d%s" "$RED" "$count" "$RESET"
	fi
}

main() {
	printf "%s %s %s %s\n" "$(tor)" "$(vpn)" "$(dns)" "$(leaks)"
}

main
