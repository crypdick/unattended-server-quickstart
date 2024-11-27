# unattended-server-quickstart
A script to quickly set up an unattended server, with automatic updating and rebooting.

It does the following:

1) enables automatic updates
2) enable automatic reboots, if required for updates
3) sets up time syncronization (NTP)


## Quick Start
Run this command as root:

```bash
curl -s https://raw.githubusercontent.com/crypdick/unattended-server-quickstart/main/unattended_server_quickstart.sh | sudo bash
```