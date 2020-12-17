#!/usr/bin/env perl

use strict;
use warnings;
use Config::Simple;
use Getopt::Long qw(:config no_ignore_case);

sub version
{
    print "version 0.1\n";
    exit(0);
}

sub help
{
    print <<HELP;

$0 - Helps you to hide network services using port-knocking and knockd

Usage: $0 [option(s)] -p <port> -s <sequence> -i <interface> --hide/--show

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

Examples:

    $0 -p 22 -n SSH -s 123,666,1234,8483,2634,134 -i eth0 --hide
    $0 -p 21 -r DROP -i wlan0 -l /var/log/mylog.log
    $0 -p 80 --show

Defaults:

    Log file: /var/log/knockd.log
    Protocol: TCP
    Reject with: REJECT (see man iptables(8) for more options)
    Interface: eth0
    Sequence: 5 random ports
    Name: The port informed by --port

Author:

    Lucas V. Araujo <lucas.vieira.ar\@disroot.org>
    GitHub: https://github.com/LvMalware
    

HELP
    exit 0;
}

sub path_of
{
    my ($command) = @_;
    my $path = `which $command` || "";
    $path =~ s/\n//g;
    return $path
}

sub find_pkg
{
    my $info = Config::Simple->new("/etc/os-release");
    my $distro = $info->param("ID_LIKE") || $info->param("ID");
    my $pkg = path_of('echo') . " [!] Please, install";
    if ($distro =~ /fedora/i)
    {
        $pkg = path_of('yum') . " install -y";
    }
    elsif ($distro =~ /debian/i)
    {
        $pkg = path_of('apt') . " install -y";
    }
    elsif ($distro =~ /arch/i)
    {
        $pkg = path_of('pacman') . " -Sy";
    }
    elsif ($distro =~ /void/i)
    {
        $pkg = path_of('xbps-install') . " -y";
    }
    $pkg
}

my $knock       = path_of('knock');
my $iptables    = path_of('iptables');
my $persistent  = path_of('iptables-persistent') ||
                  path_of('netfilter-persistent');
my $knockd_conf = "/etc/knockd.conf";
my $pkg_install = find_pkg();

$| = 1;

sub close_section
{
    my ($port, $proto, $name, $sequence) = @_;
    my $section = <<CLOSE_SECTION;
[close$name]
    sequence    =   $sequence
    seq_timeout =   10
    command     =   $iptables -D INPUT -s %IP% -p $proto --dport $port -j ACCEPT
    tcpflags    =   syn

CLOSE_SECTION

    return $section
}

sub open_section
{
    my ($port, $proto, $name, $sequence) = @_;
    my $section = <<OPEN_SECTION;
[open$name]
    sequence    =   $sequence
    seq_timeout =   10
    command     =   $iptables -I INPUT 1 -s %IP% -p $proto --dport $port -j ACCEPT
    tcpflags    =   syn

OPEN_SECTION

    return $section
}

sub find
{
    my ($content, $port, $proto) = @_;
    my $search = "-p $proto --dport $port";
    my $index1 = index($content, "[open");
    my $index2 = index($content, "[close", $index1);
    my ($index_open, $len_open, $index_close, $len_close) = (0, 0, 0, 0);
    while ($index1 > 0)
    {
        if (substr($content, $index1, $index2 - $index1) =~ /$search/)
        {
            $index_open = $index1;
            $len_open = $index2 - $index1;
            $index_close = $index2;
            $index1 = index($content, "[open", $index2);
            $index1 = length($content) if ($index1 == -1);
            $len_close = $index1 - $index2;
            last;
        }
        $index1 = index($content, "[open", $index2);
        $index2 = index($content, "[close", $index1);
    }
    ($index_open, $len_open, $index_close, $len_close)
}

sub options
{
    my ($content) = @_;
    my $index = index $content, "[options]";
    return (0, 0) if ($index == -1);
    my $length = index($content, "[open", $index) - $index;
    ($index, $length)
}

sub main
{
    my $port            = 0;
    my $name            = "";
    my $sequence        = "";
    my $protocol        = "tcp";
    my $reject_with     = "REJECT";
    my $interface       = "eth0";
    my $logfile         = "/var/log/knockd.log";
    
    my ($hide, $show);

    GetOptions(
        "h|help"        => \&help,
        "H|hide"        => \$hide,
        "S|show"        => \$show,
        "p|port=i"      => \$port,
        "n|name=s"      => \$name,
        "v|version"     => \&version,
        "P|protocol"    => \$protocol,
        "s|sequence=s"  => \$sequence,
        "r|reject=s"    => \$reject_with,
        "i|interface=s" => \$interface,
        "l|logfile=s"   => \$logfile,
    ) || return help();

    die "[!] $0 must run as root\n" if $> != 0;

    system(split / /, "$pkg_install knockd") unless $knock;
    system(split / /, "$pkg_install iptables") unless $iptables;
    system(split / /, "$pkg_install iptables-persistent") unless $persistent;
    $knock = path_of('knock') || return 1;
    $iptables = path_of('iptables') || return 1;
    $persistent = path_of('iptables-persistent') || 
                  path_of('netfilter-persistent') || return 1;
  
    die "[!] No service to hide" unless $port;
    die "[!] You must use either --hide or --show\n" unless $hide xor $show;
    
    unless ($show || $sequence)
    {
        print "No port sequence was provided. Do you want to generate " .
              "one with 5 random ports? (Y/N) ";
        my $choice = uc(substr(<STDIN>, 0, 1));
        if ($choice eq "Y")
        {
           $sequence = join ',', map { int(rand(65500) + 22) } 1 .. 5;
        }
        else
        {
            print "Enter the port sequence: ";
            $sequence = <STDIN>;
            chomp $sequence;
            die "[!] No sequence" unless $sequence;
            $sequence =~ s/ /,/g;
        }
    }

    $name = $port unless $name;
    $name = uc($name);
    
    my $close_seq = join ',', reverse split /,/, $sequence;

    print "[+] open$name sequence: $sequence\n" if $hide;
    print "[+] close$name sequence: $close_seq\n" if $hide;
    
    print "[+] Reading $knockd_conf ";
    open my $file, "<$knockd_conf" || die "Can't open $knockd_conf for reading";
    my $content = join '', <$file>;
    close $file;
    print "[OK]\n";

    print "[+] Processing older entries ";
    my ($idx_o, $len_o, $idx_c, $len_c) = find($content, $port, $protocol);
    print "[OK]\n";
    
    print "[+] Generating new entries ";
    my $open = $hide ? open_section($port, $protocol, $name, $sequence) : "";
    my $close = $hide ? close_section($port, $protocol, $name, $sequence) : "";
    print "[OK]\n";

    if ($len_o && $len_c)
    {
        print "[+] Replacing old entries ";
        substr($content, $idx_c, $len_c) = $close;
        substr($content, $idx_o, $len_o) = $open;
        print "[OK]\n";
    }
    else
    {
        print "[+] Inserting new entries ";
        $content .= $open . $close;
        print "[OK]\n";
    }
    
    print "[+] Updating knockd options ";
    my ($idx_opt, $len_opt) = options($content);
    my $options = substr($content, $idx_opt, $len_opt);
    if ($options =~ /logfile *= *([^\n]+)/)
    {
        $options =~ s/$1/$logfile/;
    }
    else
    {
        $options .= "    logfile     =    $logfile\n";
    }
    if ($options =~ /interface += +([^\n]+)/)
    {
        $options =~ s/$1/$interface/;
    }
    else
    {
        $options .= "    interface   =    $interface\n";
    }
    substr($content, $idx_opt, $len_opt) = $options;
    print "[OK]\n";
    
    print "[+] Saving '$knockd_conf' ";
    open $file, ">$knockd_conf" || die "Can't open $knockd_conf for writing";
    print $file $content;
    close $file;
    print "[OK]\n";

    if ($hide)
    {
        print "[+] Inserting iptables rules for current connections ";
        system("$iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT >/dev/null 2>&1");
        system("$iptables -A INPUT -p $protocol -m state --state ESTABLISHED,RELATED -j ACCEPT >/dev/null 2>&1");
        print "[OK]\n";
        
        print "[+] Blocking new connections to port $port ";
        system("$iptables -A INPUT -p $protocol --dport $port -j $reject_with >/dev/null 2>&1");
        print "[OK]\n";
    }
    elsif ($show)
    {
        print "[+] Unblocking connections to port $port ";
        system("$iptables -D INPUT -p $protocol --dport $port -j $reject_with >/dev/null 2>&1");
        print "[OK]\n";
    }
    
    print "[+] Saving iptables rules ";
    system("$persistent save >/dev/null 2>&1");
    system("$persistent reload >/dev/null 2>&1");
    print "[OK]\n";
    
    print "[+] (Re)starting knockd ";
    system("service knockd restart >/dev/null 2>&1");
    print "[OK]\n";

    0;
}

exit main;
