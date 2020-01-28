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
package NethServer::Database;

sub TIEHASH {
    my $class = shift;
    my $connstring = shift;
    my @parts = split(/;/, $connstring);

    if($parts[0] =~ /::/) {
        # Remove any path prefix from the module name. This is 
        # almost equivalent to basename():            
        $parts[0] = (split(m|/|, $parts[0]))[-1];
    } else {
        unshift(@parts, 'esmith::config');
    }

    if( ! eval "require $parts[0]; 1") {    
        die("Cannot load module: $@");
    }
    return $parts[0]->TIEHASH($parts[1], @parts[2..$#parts], @_);
}

1;