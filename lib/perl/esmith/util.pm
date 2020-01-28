#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::util;

use strict;

use Text::Template 'fill_in_file';
use POSIX qw (setsid);
use Errno;
use Carp;
use esmith::db;
use esmith::DB;
use esmith::ConfigDB;
use Net::IPv4Addr qw(:all);

use File::Basename;
use File::stat;
use FileHandle;

use NethServer::Password;

=pod

=head1 NAME

esmith::util - Utilities for e-smith server and gateway development

=head1 VERSION

This file documents C<esmith::util> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::util;

=head1 DESCRIPTION

This module provides general utilities of use to developers of the
e-smith server and gateway.

=head1 GENERAL UTILITIES

=head2 setRealToEffective()

Sets the real UID to the effective UID and the real GID to the effective
GID.

=begin testing

use_ok('esmith::util');

=end testing

=cut

sub setRealToEffective ()
{
    $< = $>;
    $( = $);
}

=pod

=head2 processTemplate({ CONFREF => $conf, TEMPLATE_PATH => $path })

B<Depreacted> interface to esmith::templates::processTemplate().

=cut

sub processTemplate
{
    require esmith::templates;
    goto &esmith::templates::processTemplate;
}

#------------------------------------------------------------

=pod

=head2 chownfile($user, $group, $file)

This routine changes the ownership of a file, automatically converting
usernames and groupnames to UIDs and GIDs respectively.

=cut

sub chownFile ($$$)
{
    my ( $user, $group, $file ) = @_;

    unless ( -e $file )
    {
        warn("can't chownFile $file: $!\n");
        return;
    }
    my $uid = defined $user  ? getpwnam($user)  : stat($file)->uid;
    my $gid = defined $group ? getgrnam($group) : stat($file)->gid;

    chown( $uid, $gid, $file );
}

=pod

=head2 determineRelease()

Returns the current release version of the software.

=cut

sub determineRelease()
{
    my $unknown = "(unknown version)";

    my $db = esmith::ConfigDB->open() or return $unknown;

    my $sysconfig = $db->get("sysconfig") or return $unknown;

    my $release = $sysconfig->prop("ReleaseVersion") || $unknown;

    return $release;
}

=pod

=head1 NETWORK ADDRESS TRANSLATION UTILITIES

=head2 IPquadToAddr($ip)

Convert IP address from "xxx.xxx.xxx.xxx" notation to a 32-bit
integer.

=cut

sub IPquadToAddr ($)
{
    my ($quad) = @_;
    return 0 unless defined $quad;
    if ( $quad =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ )
    {
        return ( $1 << 24 ) + ( $2 << 16 ) + ( $3 << 8 ) + $4;
    }
    return 0;
}

=pod

=head2 IPaddrToQuad($address)

Convert IP address from a 32-bit integer to "xxx.xxx.xxx.xxx"
notation.

=cut

sub IPaddrToQuad ($)
{
    my ($addrBits) = @_;
    return sprintf( "%d.%d.%d.%d",
        ( $addrBits >> 24 ) & 0xff,
        ( $addrBits >> 16 ) & 0xff,
        ( $addrBits >> 8 ) & 0xff,
        $addrBits & 0xff );
}

=pod

=head2 IPaddrToBackwardQuad($address)

Convert IP address from a 32-bit integer to reversed
"xxx.xxx.xxx.xxx.in-addr.arpa" notation for BIND files.

=cut

sub IPaddrToBackwardQuad ($)
{
    my ($addrBits) = @_;
    return sprintf(
        "%d.%d.%d.%d.in-addr.arpa.",
        $addrBits & 0xff,
        ( $addrBits >> 8 ) & 0xff,
        ( $addrBits >> 16 ) & 0xff,
        ( $addrBits >> 24 ) & 0xff
    );
}

=pod

=head2 computeNetworkAndBroadcast($ipaddr, $netmask)

Given an IP address and netmask (both in "xxx.xxx.xxx.xxx" format)
compute the network and broadcast addresses and output them in the
same format.

=cut

sub computeNetworkAndBroadcast ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my ( $network, $msk ) = ipv4_network( $ipaddr, $netmask );
    my $broadcast = ipv4_broadcast( $ipaddr, $netmask );

    return ( $network, $broadcast );
}

=pod

=head2 computeLocalNetworkPrefix($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkPrefix
function computes the network prefix for local machines.

i.e. for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
this function will return "192.168.8.".

This string is suitable for use in configuration files (such as
/etc/proftpd.conf) when the more precise notation

    xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy

is not supported.

=cut

sub computeLocalNetworkPrefix ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my ( $net, $msk ) = ipv4_network( $ipaddr, $netmask );
    $net =~ s/(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})/$1/;

    return $net;
}

=pod

=head2 computeAllLocalNetworkPrefixes ($ipaddress, $netmask)

 Given an IP address and netmask, the computeAllLocalNetworkPrefixes
 function computes the network prefix or list of prefixes that
 fully describe the network to which the IP address belongs.

 examples:

 - for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
 will return an array with a first (and only) element of "192.168.8".

 - for an IP address of 192.168.8.4 and netmask of 255.255.254.0,
 will return the array [ '192.168.8', '192.168.9' ].

 This array is suitable for use in configuration of tools such as
 djbdns where other network notations are not supported.

=begin testing

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.254.0")],
    ['192.168.8', '192.168.9' ],
    "/23 network"
    );

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.255.255")],
    ['192.168.8.4'],
    "/32 network"
    );

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.255.0")],
    ['192.168.8'],
    "/24 network"
    );

=end testing

=cut

sub computeAllLocalNetworkPrefixes
{
    my ( $ipaddr, $netmask ) = @_;

    my $ipaddrBits  = IPquadToAddr($ipaddr);
    my $netmaskBits = IPquadToAddr($netmask);
    my $networkBits = $ipaddrBits & $netmaskBits;

    # first, calculate the prefix (/??) given the netmask
    my $len = 0;
    for ( my $bits = $netmaskBits ; $bits & 0xFFFFFFFF ; $bits <<= 1 )
    {
        $len++;
    }

    # Here's where the magic starts...
    #
    # next, calculate the number of networks we expect to generate and
    # the incrementing value for each network.
    my $number_of_nets = 1 << ( ( 32 - $len ) % 8 );
    my $one_net = 1 << ( 3 - ( int $len / 8 ) ) * 8;
    my @networks;
    while ( $number_of_nets-- )
    {
        my $network = IPaddrToQuad($networkBits);

        # we want to strip off the trailing ``.0'' for /24 or larger networks
        if ( $len <= 24 )
        {
            $network =~ s/\.0$//;
        }

        # we want to continue to strip off trailing ``.0'', one more for
        # /9 to /16, two more for /1 to /8
        $network =~ s/\.0$// if ( $len <= 16 );
        $network =~ s/\.0$// if ( $len <= 8 );

        # push the resulting network into an array that we'll return;
        push @networks, $network;

        # increment the network by ``one'', relative to the size of networks
        # we're dealing with
        $networkBits += $one_net;
    }
    return (@networks);
}

=pod

=head2 computeLocalNetworkShortSpec($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkShortSpec
function computes a valid xxx.xxx.xxx.xxx/yyy specifier where yyy
is the number of bits specifying the network.

i.e. for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
this function will return "192.168.8.0/24".

This string is suitable for use in configuration files (such as
/etc/proftpd.conf) when the more precise notation

    xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy

is not supported.

=cut

sub computeLocalNetworkShortSpec ($$)
{
    my ( $ipaddr, $netmask ) = @_;
    my ( $net, $mask ) = ipv4_network( $ipaddr, $netmask );
    return "$net/$mask";
}

=pod

=head2 computeLocalNetworkSpec($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkSpec function
computes a valid xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy specifier.

=cut

sub computeLocalNetworkSpec ($$)
{
    my ( $ipaddr, $netmask ) = @_;
    my ( $net, $mask ) = ipv4_network( $ipaddr, $netmask );
    $mask = ipv4_cidr2msk($mask);
    return "$net/$mask";
}

=pod

=head2 computeNetmaskFromBits ($bits)

Given a number of bits of network address, calculate the appropriate
netmask.

=cut

sub computeNetmaskFromBits ($)
{
    my ($ones) = @_;

    return ipv4_cidr2msk($ones);
}

=pod

=head2 computeLocalNetworkReversed($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkReversed
function computes the appropriate DNS domain field.

NOTE: The return value is aligned to the next available byte boundary, i.e.

     192.168.8.4/255.255.255.0 returns "8.168.192.in-addr.arpa."
     192.168.8.4/255.255.252.0 returns "168.192.in-addr.arpa."
     192.168.8.4/255.255.0.0   returns "168.192.in-addr.arpa."
     192.168.8.4/255.252.0.0   returns "192.in-addr.arpa."
     192.168.8.4/255.0.0.0     returns "192.in-addr.arpa."

This string is suitable for use in BIND configuration files.

=cut

sub computeLocalNetworkReversed ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my @addressBytes = split ( /\./, $ipaddr );
    my @maskBytes    = split ( /\./, $netmask );

    my @result;

    push ( @result, "in-addr.arpa." );

    foreach (@maskBytes)
    {
        last unless ( $_ eq "255" );

        unshift ( @result, shift (@addressBytes) );
    }

    return join ( '.', @result );
}

=pod

=head2 computeHostRange($ipaddr, $netmask)

Given a network specification (IP address and netmask), compute
the total number of hosts in that network, as well as the first
and last IP addresses in the range.

=cut

sub computeHostRange ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my $ipaddrBits   = IPquadToAddr($ipaddr);
    my $netmaskBits  = IPquadToAddr($netmask);
    my $hostmaskBits = ( ( ~$netmaskBits ) & 0xffffffff );

    my $firstAddrBits = $ipaddrBits & $netmaskBits;
    my $lastAddrBits  = $ipaddrBits | $hostmaskBits;

    my $totalHosts = 1;

    for ( ; $hostmaskBits ; $hostmaskBits /= 2 )
    {
        if ( ( $hostmaskBits & 0x1 ) == 0x1 )
        {
            $totalHosts *= 2;
        }
    }

    return ( $totalHosts, IPaddrToQuad($firstAddrBits),
        IPaddrToQuad($lastAddrBits) );
}

=head2 backgroundCommand($delaySec, @command)

Run command in background after a specified delay.

=cut

sub backgroundCommand ($@)
{
    my ( $delaySec, @command ) = @_;

    # now would be a good time to flush output buffers, so the partial
    # buffers don't get copied

    $| = 1;
    print "";

    # create child process
    my $pid = fork;

    # if fork failed, bail out
    die "Cannot fork: $!" unless defined($pid);

    # If fork succeeded, make parent process return immediately.
    # We are not waiting on the child, so it will become a zombie
    # process when it completes. However, this subroutine is only
    # intended for use by the e-smith signal-event program, which
    # doesn't run very long. Once the parent terminates, the zombie
    # will become owned by "init" and will be reaped automatically.

    return if ($pid);

    # detach ourselves from the terminal
    setsid || die "Cannot start a new session: $!";

    # change working directory
    chdir "/";

    # clear file creation mask
    umask 0;

    # close STDIN, STDOUT, and STDERR
    close STDIN;
    close STDOUT;
    close STDERR;

    # reopen stderr, stdout, stdin
    open( STDIN, '/dev/null' );

    my $loggerPid = open( STDOUT, "|-" );
    die "Can't fork: $!\n" unless defined $loggerPid;

    unless ($loggerPid)
    {
        exec qw(/usr/bin/logger -p local1.info -t e-smith-bg);
    }

    open( STDERR, '>&STDOUT' );

    # make child wait for specified delay.
    sleep $delaySec;

    # execute command
    exec { $command[0] } @command;
}

=pod

=head1 HASH UTILITIES

=head2 genRandomHash()

Returns a random generated sha1 hash using urandom.
Returns undef if the hash could not be generated/retrieved.


=cut

sub genRandomHash
{
    return NethServer::Password->new(undef, {'symbols' => ['a'..'f', '0'..'9'], 'length' => 40})->getAscii();
}


=pod

=head1 SERVICE MANAGEMENT UTILITIES

=head2 serviceControl()

Manage services - stop/start/restart/reload/graceful

Returns 1 for success, 0 if something went wrong, fatal exception on bad
arguments.

    serviceControl(
        NAME=>serviceName,
        ACTION=>start|stop|restart|reload|graceful
        [ BACKGROUND=>true|false (default is false) ]
    );

EXAMPLE:

    serviceControl( NAME=>'httpd-e-smith', ACTION=>'reload' );

NOTES:

The BACKGROUND parameter is optional and can be set to true if
start/stop/restart/etc. is to be done in the background (with
backgroundCommand()) rather than synchronously.

CONVENTIONS:

This command is the supported method for action scripts, blade handlers, etc.,
to start/stop/restart their services. Currently this is done via the rc7
symlinks, but this may change one day. Using this function gives us one
location to change this behaviour if desired, instead of hunting all over
every scrap of code. Please use it.

=cut

sub serviceControl
{
    my %params = @_;

    my $serviceName = $params{NAME};
    unless ( defined $serviceName )
    {
        die "serviceControl: NAME must be specified";
    }

    my $serviceAction = $params{ACTION};
    unless (defined $serviceAction)
    {
        die "serviceControl: ACTION must be specified";
    }

    my ($startScript) = glob("/etc/rc.d/init.d/$serviceName");
    unless ( -e $startScript )
    {
	$startScript = "/etc/rc.d/init.d/$serviceName";
	unless ( -e $startScript) {
		warn "serviceControl: startScript not found "
              	. "for service $serviceName\n";
            		return 0;
	}
   }

   my $background = $params{'BACKGROUND'} || 'false';

   if ( $background eq 'true' )
   {
        backgroundCommand( 0, $startScript, $serviceAction );
   }
   elsif ( $background eq 'false' )
   {
        unless ( system( $startScript, $serviceAction ) == 0 )
        {
            warn "serviceControl: "
              . "Couldn't system($startScript, $serviceAction): $!\n";
            return 0;
        }
   }
   else
   {
        die "serviceControl: Unsupported BACKGROUND=>$background";
   }
    return 1;
}

=head2 getLicenses()

Return all available licenses

In scalar context, returns one string combining all licenses
In array context, returns an array of individual licenses

Optionally takes a language tag to be used for retrieving the licenses,
defaulting to the locale of the server.

=for testing
$ENV{ESMITH_LICENSE_DIR} = "10e-smith-lib/licenses";
ok(-d $ENV{ESMITH_LICENSE_DIR}, "License dir for testing exists");
like($l = esmith::util::getLicenses("fr_CA"), qr/Je suis/, "Found french license");
like($l = esmith::util::getLicenses("en_US"), qr/I am/,    "Found english license");

=cut

sub getLicenses
{
    my ($locale) = @_;

    if ($locale)
    {
        $locale =~ s/-(\S\S)/_\U$1/;
    }
    else
    {
        my $db = esmith::ConfigDB->open();

        my ( $lang, @rest ) = $db->getLocale();

        $lang = $lang || "en_US";

        $locale = $lang;
    }

    my $base_dir = $ENV{ESMITH_LICENSE_DIR} || "/etc/e-smith/licenses";

    $locale = "en_US" unless ( -d "${base_dir}/${locale}" );

    my $dir = "${base_dir}/${locale}";

    my @licenses;

    opendir( DIR, $dir ) || die "Couldn't open licenses directory\n";

    foreach my $license ( readdir(DIR) )
    {
        my $file = "${dir}/${license}";

        next unless ( -f $file );

        open( LICENSE, $file ) || die "Couldn't open license $file\n";

        push @licenses, <LICENSE>;

        close LICENSE;
    }

    return wantarray ? @licenses : "@licenses";
}

=item B<initialize_default_databases>

Initialize all databases located at /etc/e-smith/db.

=cut

sub initialize_default_databases
{

    # Optionally take an argument to the db root, for testing purposes.
    my %defaults = (
        dbroot => '/etc/e-smith/db',
        dbhome => '/var/lib/nethserver/db',
        old_dbhome => '/home/e-smith',
    );
    my %args   = ( %defaults, @_ );
    my $dbroot = $args{dbroot};
    my $dbhome = $args{dbhome};
    my $old_dbhome = $args{old_dbhome};

    local *DH;
    opendir DH, $dbroot
      or die "Could not open $dbroot: $!";

    my @dirs = readdir(DH);

    # Move all databases to new home first them migrate data
    # Untaint db names while we are at it.
    foreach my $file ( map { /(.+)/ ; $1 } grep !/^\./, @dirs )
    {
        if (-f "${old_dbhome}/$file")
        {
            if (-l "${old_dbhome}/$file")
            {
                warn "symlink called ${old_dbhome}/$file exists\n";
		next;
            }

            if (-s "${dbhome}/$file")
            {
                warn "${old_dbhome}/$file and ${dbhome}/$file exist\n";
                rename "${dbhome}/$file", "${dbhome}/$file." . time;
            }

	    warn "Rename ${old_dbhome}/$file => ${dbhome}/$file\n";
	    rename "${old_dbhome}/$file", "${dbhome}/$file";
        }
    }

    foreach my $file ( grep !/^\./, @dirs )
    {
        # Untaint the result of readdir. As we're expecting filenames like
        # 'configuration' and 'ipphones', lets restrict input to those.
        if ($file =~ /(^[A-Za-z0-9_\.-]+$)/)
        {
            $file = $1;
        }
        else
        {
	    warn "Not processing unexpected file $file\n";
            next;
        }

        eval
        {
            my $h = esmith::ConfigDB->open($file);
            if ($h)
            {
                warn "Migrating existing database $file\n";

                # Convert old data to new format, and add any new defaults. Note
                # that migrate returns FALSE on fatal errors. Report those to
                # syslog. The error should still be in $@.
                unless ( $h->migrate() )
                {
                    warn "Migration of db $file failed: " . esmith::DB->error;
                }
            }
            else
            {
                warn "Creating database $file and setting defaults\n";

                # create() and load defaults
                unless ( $h = esmith::ConfigDB->create($file) )
                {
                    warn "Could not create $file db: " . esmith::DB->error;
                }
            }

            $h->close;
        };
        if ($@)
        {
            warn "Fatal error while processing db $file: $@\n";
        }
    }
    return 1;
}

=head1 AUTHOR

Mitel Networks Corp.

For more information, see http://www.e-smith.org/

=cut

1;
