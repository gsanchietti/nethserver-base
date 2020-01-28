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
package NethServer::Database::Group;

sub TIEHASH {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key = shift;
    my @grent = getgrnam($key);
    if( ! @grent) {
        return undef;
    }
    my @fields = qw(name passwd gid members);
    my %H = ();
    @H{@fields} = @grent;
    my $value = 'group';
    foreach (keys %H) {
        if(defined $H{$_}) {
            $value .= '|' . $_ . '|' . $H{$_};
        }
    }
    return $value;
}

sub EXISTS {
    my $self = shift;
    my $key = shift;
    return defined getgrnam($key);
}

sub FIRSTKEY {
    setgrent();
    return scalar getgrent();
}

sub NEXTKEY {
    return scalar getgrent();
}

1;