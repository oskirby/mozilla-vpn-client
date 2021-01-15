#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2015-2020 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
#

echo "Running mozillavpn forked copy of wg-quick script."

set -e -o pipefail
shopt -s extglob
export LC_ALL=C

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
export PATH="${SELF%/*}:$PATH"

WG_CONFIG=""
INTERFACE=""
ADDRESSES=( )
DNS=( )
DNS_SEARCH=( )
TABLE=""
CONFIG_FILE=""
PROGRAM="${0##*/}"
ARGS=( "$@" )

cmd() {
	echo "[#] $*" >&2
	"$@"
}

die() {
	echo "$PROGRAM: $*" >&2
	exit 1
}

parse_options() {
	local interface_section=0 line key value stripped v
	CONFIG_FILE="$1"
	[[ $CONFIG_FILE =~ ^[a-zA-Z0-9_=+.-]{1,15}$ ]] && CONFIG_FILE="/etc/wireguard/$CONFIG_FILE.conf"
	[[ -e $CONFIG_FILE ]] || die "\`$CONFIG_FILE' does not exist"
	[[ $CONFIG_FILE =~ (^|/)([a-zA-Z0-9_=+.-]{1,15})\.conf$ ]] || die "The config file must be a valid interface name, followed by .conf"
	CONFIG_FILE="$(readlink -f "$CONFIG_FILE")"
	((($(stat -c '0%#a' "$CONFIG_FILE") & $(stat -c '0%#a' "${CONFIG_FILE%/*}") & 0007) == 0)) || echo "Warning: \`$CONFIG_FILE' is world accessible" >&2
	INTERFACE="${BASH_REMATCH[2]}"
	shopt -s nocasematch
	while read -r line || [[ -n $line ]]; do
		stripped="${line%%\#*}"
		key="${stripped%%=*}"; key="${key##*([[:space:]])}"; key="${key%%*([[:space:]])}"
		value="${stripped#*=}"; value="${value##*([[:space:]])}"; value="${value%%*([[:space:]])}"
		[[ $key == "["* ]] && interface_section=0
		[[ $key == "[Interface]" ]] && interface_section=1
		if [[ $interface_section -eq 1 ]]; then
			case "$key" in
			Address) ADDRESSES+=( ${value//,/ } ); continue ;;
			DNS) for v in ${value//,/ }; do
				[[ $v =~ (^[0-9.]+$)|(^.*:.*$) ]] && DNS+=( $v ) || DNS_SEARCH+=( $v )
			done; continue ;;
			Table) TABLE="$value"; continue ;;
			esac
		fi
		WG_CONFIG+="$line"$'\n'
	done < "$CONFIG_FILE"
	shopt -u nocasematch
}

add_if() {
	local ret
	if ! cmd ip link add "$INTERFACE" type wireguard; then
		ret=$?
		[[ -e /sys/module/wireguard ]] || ! command -v "${WG_QUICK_USERSPACE_IMPLEMENTATION:-wireguard-go}" >/dev/null && exit $ret
		echo "[!] Missing WireGuard kernel module. Falling back to slow userspace implementation." >&2
		cmd "${WG_QUICK_USERSPACE_IMPLEMENTATION:-wireguard-go}" "$INTERFACE"
	fi
}

del_if() {
	local table
	[[ $HAVE_SET_DNS -eq 0 ]] || unset_dns
	[[ $HAVE_SET_FIREWALL -eq 0 ]] || remove_firewall
	if [[ -z $TABLE || $TABLE == auto ]] && get_fwmark table && [[ $(wg show "$INTERFACE" allowed-ips) =~ /0(\ |$'\n'|$) ]]; then
		while [[ $(ip -4 rule show 2>/dev/null) == *"lookup $table"* ]]; do
			cmd ip -4 rule delete table $table
		done
		while [[ $(ip -4 rule show 2>/dev/null) == *"from all lookup main suppress_prefixlength 0"* ]]; do
			cmd ip -4 rule delete table main suppress_prefixlength 0
		done
		while [[ $(ip -6 rule show 2>/dev/null) == *"lookup $table"* ]]; do
			cmd ip -6 rule delete table $table
		done
		while [[ $(ip -6 rule show 2>/dev/null) == *"from all lookup main suppress_prefixlength 0"* ]]; do
			cmd ip -6 rule delete table main suppress_prefixlength 0
		done
	fi
	cmd ip link delete dev "$INTERFACE"
}

add_addr() {
	local proto=-4
	[[ $1 == *:* ]] && proto=-6
	cmd ip $proto address add "$1" dev "$INTERFACE"
}

set_mtu_up() {
	# Using default MTU of 1420
	cmd ip link set mtu 1420 up dev "$INTERFACE"
}

resolvconf_iface_prefix() {
	[[ -f /etc/resolvconf/interface-order ]] || return 0
	local iface
	while read -r iface; do
		[[ $iface =~ ^([A-Za-z0-9-]+)\*$ ]] || continue
		echo "${BASH_REMATCH[1]}." && return 0
	done < /etc/resolvconf/interface-order
}

HAVE_SET_DNS=0
set_dns() {
	[[ ${#DNS[@]} -gt 0 ]] || return 0
	{ printf 'nameserver %s\n' "${DNS[@]}"
	  [[ ${#DNS_SEARCH[@]} -eq 0 ]] || printf 'search %s\n' "${DNS_SEARCH[*]}"
	} | cmd resolvconf -a "$(resolvconf_iface_prefix)$INTERFACE" -m 0 -x
	HAVE_SET_DNS=1
}

unset_dns() {
	[[ ${#DNS[@]} -gt 0 ]] || return 0
	cmd resolvconf -d "$(resolvconf_iface_prefix)$INTERFACE" -f
}

add_route() {
	local proto=-4
	[[ $1 == *:* ]] && proto=-6
	[[ $TABLE != off ]] || return 0

	if [[ -n $TABLE && $TABLE != auto ]]; then
		cmd ip $proto route add "$1" dev "$INTERFACE" table "$TABLE"
	elif [[ $1 == */0 ]]; then
		add_default "$1"
	else
		[[ -n $(ip $proto route show dev "$INTERFACE" match "$1" 2>/dev/null) ]] || cmd ip $proto route add "$1" dev "$INTERFACE"
	fi
}

get_fwmark() {
	local fwmark
	fwmark="$(wg show "$INTERFACE" fwmark)" || return 1
	[[ -n $fwmark && $fwmark != off ]] || return 1
	printf -v "$1" "%d" "$fwmark"
	return 0
}

remove_firewall() {
	if type -p nft >/dev/null; then
		local table nftcmd
		while read -r table; do
			[[ $table == *" wg-quick-$INTERFACE" ]] && printf -v nftcmd '%sdelete %s\n' "$nftcmd" "$table"
		done < <(nft list tables 2>/dev/null)
		[[ -z $nftcmd ]] || cmd nft -f <(echo -n "$nftcmd")
	fi
	if type -p iptables >/dev/null; then
		local line iptables found restore
		for iptables in iptables ip6tables; do
			restore="" found=0
			while read -r line; do
				[[ $line == "*"* || $line == COMMIT || $line == "-A "*"-m comment --comment \"wg-quick(8) rule for $INTERFACE\""* ]] || continue
				[[ $line == "-A"* ]] && found=1
				printf -v restore '%s%s\n' "$restore" "${line/#-A/-D}"
			done < <($iptables-save 2>/dev/null)
			[[ $found -ne 1 ]] || echo -n "$restore" | cmd $iptables-restore -n
		done
	fi
}

HAVE_SET_FIREWALL=0
add_default() {
	local table line
	if ! get_fwmark table; then
		table=51820
		while [[ -n $(ip -4 route show table $table 2>/dev/null) || -n $(ip -6 route show table $table 2>/dev/null) ]]; do
			((table++))
		done
		cmd wg set "$INTERFACE" fwmark $table
	fi
	local proto=-4 iptables=iptables pf=ip
	[[ $1 == *:* ]] && proto=-6 iptables=ip6tables pf=ip6
	cmd ip $proto route add "$1" dev "$INTERFACE" table $table
	cmd ip $proto rule add not fwmark $table table $table
	cmd ip $proto rule add table main suppress_prefixlength 0

	local marker="-m comment --comment \"wg-quick(8) rule for $INTERFACE\"" restore=$'*raw\n' nftable="wg-quick-$INTERFACE" nftcmd 
	printf -v nftcmd '%sadd table %s %s\n' "$nftcmd" "$pf" "$nftable"
	printf -v nftcmd '%sadd chain %s %s preraw { type filter hook prerouting priority -300; }\n' "$nftcmd" "$pf" "$nftable"
	printf -v nftcmd '%sadd chain %s %s premangle { type filter hook prerouting priority -150; }\n' "$nftcmd" "$pf" "$nftable"
	printf -v nftcmd '%sadd chain %s %s postmangle { type filter hook postrouting priority -150; }\n' "$nftcmd" "$pf" "$nftable"
	while read -r line; do
		[[ $line =~ .*inet6?\ ([0-9a-f:.]+)/[0-9]+.* ]] || continue
		printf -v restore '%s-I PREROUTING ! -i %s -d %s -m addrtype ! --src-type LOCAL -j DROP %s\n' "$restore" "$INTERFACE" "${BASH_REMATCH[1]}" "$marker"
		printf -v nftcmd '%sadd rule %s %s preraw iifname != "%s" %s daddr %s fib saddr type != local drop\n' "$nftcmd" "$pf" "$nftable" "$INTERFACE" "$pf" "${BASH_REMATCH[1]}"
	done < <(ip -o $proto addr show dev "$INTERFACE" 2>/dev/null)
	printf -v restore '%sCOMMIT\n*mangle\n-I POSTROUTING -m mark --mark %d -p udp -j CONNMARK --save-mark %s\n-I PREROUTING -p udp -j CONNMARK --restore-mark %s\nCOMMIT\n' "$restore" $table "$marker" "$marker"
	printf -v nftcmd '%sadd rule %s %s postmangle meta l4proto udp mark %d ct mark set mark \n' "$nftcmd" "$pf" "$nftable" $table
	printf -v nftcmd '%sadd rule %s %s premangle meta l4proto udp meta mark set ct mark \n' "$nftcmd" "$pf" "$nftable"
	[[ $proto == -4 ]] && cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1
	if type -p nft >/dev/null; then
		cmd nft -f <(echo -n "$nftcmd")
	else
		echo -n "$restore" | cmd $iptables-restore -n
	fi
	HAVE_SET_FIREWALL=1
	return 0
}

set_config() {
	cmd wg setconf "$INTERFACE" <(echo "$WG_CONFIG")
}

cmd_usage() {
	cat >&2 <<-_EOF
	Usage: $PROGRAM [ up | down ] [ CONFIG_FILE | INTERFACE ]

	  CONFIG_FILE is a configuration file, whose filename is the interface name
	  followed by \`.conf'. Otherwise, INTERFACE is an interface name, with
	  configuration found at /etc/wireguard/INTERFACE.conf. It is to be readable
	  by wg(8)'s \`setconf' sub-command, with the exception of the following additions
	  to the [Interface] section, which are handled by $PROGRAM:

	  - Address: may be specified one or more times and contains one or more
	    IP addresses (with an optional CIDR mask) to be set for the interface.
	  - DNS: an optional DNS server to use while the device is up.
	  - Table: an optional routing table to which routes will be added; if
	    unspecified or \`auto', the default table is used. If \`off', no routes
	    are added.

	See wg-quick(8) for more info and examples.
	_EOF
}

cmd_up() {
	local i
	[[ -z $(ip link show dev "$INTERFACE" 2>/dev/null) ]] || die "\`$INTERFACE' already exists"
	trap 'del_if; exit' INT TERM EXIT
	add_if
	set_config
	for i in "${ADDRESSES[@]}"; do
		add_addr "$i"
	done
	set_mtu_up
	set_dns
	for i in $(while read -r _ i; do for i in $i; do [[ $i =~ ^[0-9a-z:.]+/[0-9]+$ ]] && echo "$i"; done; done < <(wg show "$INTERFACE" allowed-ips) | sort -nr -k 2 -t /); do
		add_route "$i"
	done
	trap - INT TERM EXIT
}

cmd_down() {
	[[ " $(wg show interfaces) " == *" $INTERFACE "* ]] || die "\`$INTERFACE' is not a WireGuard interface"
	del_if
	unset_dns || true
	remove_firewall || true
}

# ~~ function override insertion point ~~

if [[ $# -eq 1 && ( $1 == --help || $1 == -h || $1 == help ) ]]; then
	cmd_usage
elif [[ $# -eq 2 && $1 == up ]]; then
	parse_options "$2"
	cmd_up
elif [[ $# -eq 2 && $1 == down ]]; then
	parse_options "$2"
	cmd_down
else
	cmd_usage
	exit 1
fi

exit 0
