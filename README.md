# hidemyservice.pl

A perl script that helps you to hide network services on your server/machine while keeping it accessible through a port-knocking mechanism using knockd(1).

You can learn more about port-knocking and how it works <a href="https://en.wikipedia.org/wiki/Port_knocking">here</a>. The source code of knockd can be found at https://github.com/jvinet/knock/ and after installing it on your system through a package manager, the documentation can be consulted using man(1).

# Usage
```
Usage: ./hidemyservice.pl [option(s)] -p <port> -s <sequence> -i <interface> --hide/--show

Options:
    
    -h, --help          Show this help message and exit
    -H, --hide          Hide a service
    -S, --show          Show the service again
    -p, --port          The port on which the service runs
    -n, --name          The name of the service
    -v, --version       Show the programs version and exit
    -P, --protocol      The protocol on which the service is based (TCP or UDP)
    -s, --sequence      Sequence of ports to enable connection to the service
                        (The ports are separated by a comma like: 555,321,345)
    -r, --reject        The method to be used by iptables to reject packets
    -i, --interface     Default interface on which knockd will listen
    -l, --logfile       Full path to save knockd logs

```

# How this script works

First, the script will insure the installation of all the tools necessary (such as knockd and iptables-persistent). Next it will modify the default configuration file of knockd (usually located at /etc/knockd) and insert entries to open and close the access to your service upon the knocking of the defined port sequence. Next it will block all the traffic to said port through iptables(8).

# Warning

This is just a script to automate the task of installing and setting up a hidden service with knockd. This is a relatively simple task, but still very error-prone even with this script as it was not tested on many different environments and may contain bugs. So if you decide to use it, make sure you have a way to acess the machine even if you're locked out by the firewall, so to be able to correct any configuration errors that may occur.

# Author

Lucas V. Araujo <lucas.vieira.ar@disroot.org>


