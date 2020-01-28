#!/usr/bin/perl

#
# Copyright (C) 2013 Nethesis S.r.l.
# http://www.nethesis.it - support@nethesis.it
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
# along with NethServer.  If not, see <http://www.gnu.org/licenses/>.
#

package NethServer::Migrate;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(migrateDir parseShadow);

use File::stat;
use Carp;

=head1 NAME

NethServer::Migrate - NethServer Migration tools

=cut

=head1 FUNCTIONS 

=head2 migrateDir($srcDir, $dstDir) 

Copy or Move $sourceDir contents to $destDir. Both directories must exist.

=cut
sub migrateDir($$)
{
    my $s = shift; # source directory
    my $d = shift; # dest directory

    # trim ending slashes:
    $s =~ s|/+$||;
    $d =~ s|/+$||;

    if ( ! -d $s) {
	carp "[ERROR] Source $s is not a directory!\n";
	return 0;
    }

    if ( ! -d $d) {
	carp "[ERROR] Destination $d is not a directory!\n";
	return 0;
    }

    my $statS = stat($s);

    if ( ! $statS) {
	carp "[ERROR] Could not stat() source directory $s!\n";
	return 0;
    }

    my $statD = stat($d);

    if ( ! $statD) {
	carp "[ERROR] Could not stat() destination directory $d!\n";
	return 0;
    }

    my @sources = grep { $_ !~ m|/\.\.?$| } glob($s . '/{.*,*}');

    if( ! @sources) {
	print "[WARNING] No files to migrate in $s\n";
	return 1;
    }

    # Check if directories are on the same filesystem:
    if ($statS->dev == $statD->dev) {
	# Use MOVE
	print "[INFO] Move $s to $d\n";
	system('mv', '-t', $d, @sources);
    } else {
	# Use COPY
	print "[INFO] Copy $s to $d\n";
	system('cp', '-a', '-t', $d, @sources);
    }

    if($? != 0) {
	return 0; # failure
    }

    return 1; # success
}


=head2 parseShadow($shadowFile)

Read secret hashes from $shadowFile and returns a perl hash reference,
indexed by user name.  Each entry is a shadow structure; see man
shadow(3).

=cut
sub parseShadow($)
{
    my $shadowFile = shift;

    my %h = ();
    my @fields = (qw(
       namp
       pwdp
       lstchg
       min
       max
       warn
       inact
       expire
       flag
    ));
   
    if( ! open(FH, '<', $shadowFile)) {
	carp "[ERROR] Could not open $shadowFile for reading!";
	return {};
    }

    while(<FH>) {
	chomp($_);
	my %entry = ();
	@entry{@fields} = split(':', $_, 9);
	$h{$entry{namp}} = \%entry;
    }

    close(FH);

    return \%h;
}


=head2 parseGroup($groupFile)

Read group database from $groupFile and returns a perl hash reference,
indexed by group name.  Each entry is a group entry structure; see man
getgrnam(3) or <grp.h>.

=cut
sub parseGroup($)
{
    my $groupFile = shift;

    my %h = ();
    my @fields = (qw(
       name
       passwd
       gid
       mem
    ));
   
    if( ! open(FH, '<', $groupFile)) {
	carp "[ERROR] Could not open $groupFile for reading!";
	return {};
    }

    while(<FH>) {
	chomp($_);
	my %entry = ();
	@entry{@fields} = split(':', $_, 4);
	$h{$entry{name}} = \%entry;
    }

    close(FH);

    return \%h;
}


1;
