#----------------------------------------------------------------------
# Copyright 1999-2005 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::ethernet;

#----------------------------------------------------------------------

use strict;

=head1 NAME

esmith::ethernet - Ethernet-related utility routines for e-smith

=head1 VERSION

This file documents C<esmith::ethernet> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::ethernet;

=head1 DESCRIPTION

This module contains routines for 


=pod

=head2 listDevices()

Query udev for all devices

=cut

sub listDevices ()
{
    my @list;
    my @files = </sys/class/net/*/device/uevent>;
    foreach my $file  (@files)
    {
        my %dev;
        my @path = split(/\//,$file);
        $dev{'INTERFACE_NAME'} = $path[4];
        open FILE, "<", $file;
        while (<FILE>) {
            $_ =~ s/\s+$//; #rstrip
            my ($key, $value) = split(/=/,$_);
            next unless ($key eq 'DRIVER');
            $dev{'ID_MODEL_FROM_DATABASE'} = $value;
        }
        close FILE;

        $file = sprintf "/sys/class/net/%s/address", $dev{'INTERFACE_NAME'};
        local $/ = undef;
        open FILE,  $file;
        binmode FILE;
        my $tmp = <FILE>;
        $tmp =~ s/\s+$//;
        $dev{'MATCHADDR'} = $tmp;
        close FILE;

        push(@list,\%dev);
    }
    
    return @list;
}



=pod

=head2 probeAdapters()

Probe for any recognised adapters

=cut

sub probeAdapters ()
{
    my $adapters  = '';
    my @devs = listDevices();
    my $index = 1;
    foreach my $nic (@devs) {
        $adapters .=
          "EthernetDriver" . $index++ . "\t" . $nic->{'INTERFACE_NAME'} . "\t"
          . $nic->{'MATCHADDR'} . "\t" . $nic->{'ID_MODEL_FROM_DATABASE'} . "\n";
    }
    return $adapters;
}


#----------------------------------------------------------------------
# Return one to make the import process return success.
#----------------------------------------------------------------------

1;

=pod

=AUTHOR

SME Server Developers <bugs@e-smith.com>

For more information see http://www.e-smith.org/

=cut

