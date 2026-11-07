#!/usr/bin/env bash
# Prepare a booted emulator for the native e2e: wait for boot, root adbd, give
# Wi-Fi the IPv4 routes the API 34 image sometimes comes up without (no route
# = no DNS = "This page could not be loaded"), and quiet ANR dialogs (TCG).
set -u
A="${ADB:-/home/box/sdk/android/platform-tools/adb} -s ${SERIAL:-emulator-5580}"
until [ "$($A shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 10; done
$A root >/dev/null; sleep 4; $A wait-for-device
# Wait for Wi-Fi to come up (its policy-routing rule appears), then find its table.
for i in $(seq 1 60); do t=$($A shell "ip rule" | sed -n 's/.*iif lo oif wlan0 lookup \([0-9a-z]*\).*/\1/p' | head -1 | tr -d '\r'); [ -n "$t" ] && break; sleep 5; done
if [ -n "$t" ] && ! $A shell "ip route show table $t" | grep -q "default via"; then
  $A shell "ip route add 10.0.2.0/24 dev wlan0 table $t; ip route add default via 10.0.2.2 dev wlan0 table $t"
fi
for s in window_animation_scale transition_animation_scale; do $A shell settings put global $s 0; done
$A shell settings put global hide_error_dialogs 1
$A shell settings put system screen_off_timeout 1800000
$A shell svc power stayon true
$A shell 'printf "HEAD / HTTP/1.0\r\nHost: www.bing.com\r\n\r\n" | toybox nc -w 8 www.bing.com 80 | head -1'
