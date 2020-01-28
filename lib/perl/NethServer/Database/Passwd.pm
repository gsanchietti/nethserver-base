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
package NethServer::Database::Passwd;

sub TIEHASH {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key = shift;
    my @pwent = getpwnam($key);
    if( ! @pwent) {
        return undef;
    }
    my @fields = qw(name passwd uid gid quota comment gecos dir shell expire);
    my %H = ();
    @H{@fields} = @pwent;
    my $value = 'passwd';
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
    return defined getpwnam($key);
}

sub FIRSTKEY {
    setpwent();
    return scalar getpwent();
}

sub NEXTKEY {
    return scalar getpwent();
}

1;