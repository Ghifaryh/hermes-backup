Monitoring: A cron watchdog job ('tailscale-wrk-aio-monitor') checks `gip-wrk-aio` Tailscale status every 5m via ~/.hermes/profiles/akane/scripts/check_wrk_aio.sh with `no_agent: true` (0 token cost).
§
Tailscale mesh nodes: gip-cloud-vps-01 (100.113.2.103), gip-wrk-aio (100.73.82.1, local subnet 192.168.75.0/24), gip-hm-stb-01 (100.84.225.86, Armbian with root on eMMC and SSD on /mnt/ssd, reaches 192.168.80.0/24). Root SSH without password works from VPS to gip-hm-stb-01 and gip-wrk-aio.
§
Network topology: gitlab-runner is at 192.168.80.155 (port 2283). Direct jump host is gip-wrk-sandbox (100.93.117.28, ens18 on 192.168.80.152), secondary jump host is gip-wrk-aio (100.73.82.1). STB gip-hm-stb-01 is at 100.84.225.86 with SSD mounted at /mnt/ssd.