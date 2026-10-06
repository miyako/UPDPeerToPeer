Prerequisites
Things that must be ready before launching the project:

4D 20R10 or later is mandatory as UDPSocket and UDPEvent classes were introduced in 20R10.
All application’s instances must run on the same local network/subnet connected via Ethernet cables (Wi-Fi is not supported as it may not reliably handle broadcasts; LAN with Ethernet cables is mandatory).
The chosen UDP discovery port (default 54321) must be allowed for both inbound and outbound traffic by any firewall, antivirus, or network policy on every machine.
No other process on the same machine may already bind to the discovery port (exclusive binding).
macOS/Windows must allow the 4D application to open network sockets (standard user rights are sufficient).

Requirements
Conditions that must remain satisfied while the system is running:

UDP broadcast packets (destination 255.255.255.255 or the configured broadcast address) must reach all participating machines.
The discovery port must remain open and unblocked for the entire lifetime of the application.

When these prerequisites and requirements are met, the Peer Discovery system starts instantly, and peers become visible within a few seconds.