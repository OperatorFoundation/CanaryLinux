# CanaryLinux
A command line tool for testing transport connections and gathering the packets for analysis. 

Canary will run a series of transport tests based on the configs that you provide. It is possible to test each transport on a different transport server based on what host information is provided in the transport config files. 

Currently Shadowsocks and Replicant tests are supported. If a different transport needs to be tested, Replicant can be setup to mimic other transports.

*Currently in development*

## Compiling the project on a Linux system:
- You will need to install libpcap-dev if you do not already have it using:
`sudo apt-get install libpcap-dev`

## Running Canary
- Transport configs should include their transport server IP and port, and should include the transport name in the name of the file.
- You should run Canary on the same platform it was compiled on
- You must run Canary with sudo in order for it to capture any data
- To run Canary with default settings simply provide the config directory for the transports you want to test as an argument:
'sudo Canary <path-to-config-directory>

