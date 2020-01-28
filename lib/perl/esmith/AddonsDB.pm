#----------------------------------------------------------------------
# Copyright 2011 Nethesis - www.nethesis.it
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::AddonsDB;

use strict;
use warnings;

use esmith::DB::db;
our @ISA = qw( esmith::DB::db );

=head1 NAME

esmith::AddonsDB - interface to nethserver addons database

=head1 SYNOPSIS

    use esmith::AddonsDB;
    my $c = esmith::AddonsDB->open;

    # everything else works just like esmith::DB::db

=head1 DESCRIPTION

This module provides an abstracted interface to the esmith domain
database.

Unless otherwise noted, esmith::AddonsDB acts like esmith::DB::db.

=cut

=head2 open()

Like esmith::DB->open, but if given no $file it will try to open the
file in the ESMITH_ADDONS_DB environment variable or addons.


=cut

sub open {
    my ($self, $file) = @_;
    $file = $file || $ENV{ESMITH_ADDONS_DB} || "addons";
    return $self->SUPER::open($file);
}

=head2 open_ro()

Like esmith::DB->open_ro, but if given no $file it will try to open the
file in the ESMITH_ADDONS_DB environment variable or addons.


=cut

sub open_ro {
    my($class, $file) = @_;
    $file = $file || $ENV{ESMITH_ADDONS_DB} || "addons";
    return $class->SUPER::open_ro($file);
}

sub addons {
    my ($self) = @_;
    return $self->get_all_by_prop(type => 'addon');
}

=head1 AUTHOR

Giacomo Sanchietti <giacomo@nethesis.it>

=head1 SEE ALSO

L<esmith::ConfigDB>

=cut

1;
