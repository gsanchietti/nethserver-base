#
# Copyright (C) 2016 Nethesis S.r.l.
# http://www.nethesis.it - nethserver@nethesis.it
#
# This script is part of NethServer.
#
# NethServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License,
# or any later version.
#
# NethServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NethServer.  If not, see COPYING.
#

use strict;
package NethServer::Database::Hostname;

use Net::DBus;

sub TIEHASH {
    my $class = shift;

    my $bus = Net::DBus->system();
    my $service = $bus->get_service("org.freedesktop.hostname1");
    my $object = $service->get_object('/org/freedesktop/hostname1');

    my $self = {
        'bus' => $bus,
        'service' => $service,
        'object' => $object,
        'keys' => [qw(
            Hostname
            StaticHostname
            PrettyHostname
            IconName
            Chassis
            Deployment
            Location
            KernelName
            KernelRelease
            KernelVersion
            OperatingSystemPrettyName
            OperatingSystemCPEName
        )],
    };
    bless $self, $class;
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key = shift;

    if( ! $self->EXISTS($key)) {
        return undef;
    }

    return $self->{'object'}->$key;
}

sub EXISTS {
    my $self = shift;
    my $key = shift;
    return grep { $_ eq $key } @{$self->{'keys'}};
}

sub FIRSTKEY {
    my $self = shift;
    values $self->{'keys'};
    return $self->NEXTKEY();
}

sub NEXTKEY {
    my $self = shift;
    my ($k, $v) = each($self->{'keys'});
    return $v;
}

sub STORE {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    if($key eq 'StaticHostname') {
        $self->{'object'}->SetStaticHostname($value, 0);
    } elsif ($key eq 'Hostname') {
        $self->{'object'}->SetHostname($value, 0);
    } elsif ($key eq 'PrettyHostname') {
        $self->{'object'}->SetPrettyHostname($value, 0);
    } elsif ($key eq 'Deployment') {
        $self->{'object'}->SetDeployment($value, 0);
    } elsif ($key eq 'Location') {
        $self->{'object'}->SetLocation($value, 0);
    }
}

1;