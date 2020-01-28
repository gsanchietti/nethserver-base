#
# NethServer Service
#

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

package NethServer::Service;

use strict;
use esmith::ConfigDB;

our $legacySupport = 1;

=head1 NAME

NethServer::Service module

=cut

=head2 ->new

Create a Service object

Arguments:

=over 1

=item $serviceName

The service to wrap

=item $configDb (optional)

An opened Configuration database

=back

=cut
sub new
{
    my $class = shift;
    my $serviceName = shift;
    my $configDb = shift;

    if( ! $configDb ) {
	$configDb = esmith::ConfigDB->open_ro() || die("Could not open ConfigDB");
    }

    my $self = {
	'serviceName' => $serviceName,
	'configDb' => $configDb,
	'verbose' => 0,
    };

    bless $self, $class;

    return $self;
}


=head2 ->start

Start the service if it is stopped

WARNING: Static invocation is supported for backward compatibility and
will be removed in the future.

=cut
sub start
{
    my $self = shift;

    if( $legacySupport && ! ref($self) ) {
	my $daemon = $self;
	$self = NethServer::Service->new($daemon);
    }

    return system('systemctl', 'start', $self->{'serviceName'}) == 0;
}


=head2 ->stop

Stop the service if it is running

WARNING: Static invocation is supported for backward compatibility and
will be removed in the future.

=cut
sub stop
{
    my $self = shift;

    if( $legacySupport && ! ref($self) ) {
	my $daemon = $self;
	$self = NethServer::Service->new($daemon);
    }

    return system('systemctl', 'stop', $self->{'serviceName'}) == 0;
}

=head2 ->condrestart

=cut
sub condrestart
{
    my $self = shift;
    return system('systemctl', 'try-restart', $self->{'serviceName'}) == 0;
}

=head2 ->restart

=cut
sub restart
{
    my $self = shift;
    return system('systemctl', 'restart', $self->{'serviceName'}) == 0;
}

=head2 ->reload

=cut
sub reload
{
    my $self = shift;
    return system('systemctl', 'reload', $self->{'serviceName'}) == 0;
}


=head2 ->is_configured

Check if the service is defined in configuration database

=cut
sub is_configured
{
    my $self = shift;
    my $record = $self->{'configDb'}->get($self->{'serviceName'});
    if(defined $record && $record->prop('type') eq 'service') {
	return 1;
    }
    return 0;
}


=head2 ->is_enabled

Check if the service is enabled in configuration database.

WARNING: Static invocation is supported for backward compatibility and
will be removed in the future. Optionally, you can pass an already
opened esmith::ConfigDB object in $configDb. Example:

  if(is_enabled($daemon)) {
     start($daemon);
  }

=cut
sub is_enabled
{
    my $self = shift;

    if( $legacySupport && ! ref($self) ) {
	my $daemon = shift;
	my $configDb = shift;

	$configDb = $daemon;
	$daemon = $self;
	$self = NethServer::Service->new($daemon, $configDb);
    }

    my $status = $self->{'configDb'}->get_prop($self->{'serviceName'}, 'status') || 'unknown';

    if($status eq 'enabled') {
	return 1;
    }

    return 0;
}

=head2 ->is_owned

Check if the service is owned by a currently installed package.

=cut
sub is_owned
{
    my $self = shift;
    my $typePath = '/etc/e-smith/db/configuration/defaults/' . $self->{'serviceName'} . '/type';

    if( -f $typePath ) {
	open(FH, '<', $typePath) || warn "[ERROR] $typePath:" . $! . "\n";
	my $line = <FH>;
	chomp $line;
	if($line eq 'service') {
	    return 1;
	}
	close(FH);
    }
    return 0;
}

=head2 ->is_running

Check if the service is running.

=cut
sub is_running
{
    my $self = shift;
    return system('systemctl', '-q', 'is-active', $self->{'serviceName'}) == 0;
}

=head2 ->is_masked

Check if the service unit is in "masked" state. See systemctl manpage.

=cut
sub is_masked
{
    my $self = shift;
    my $unitName = $self->{'serviceName'};
    my $output = qx(systemctl show --property=LoadState $unitName);
    if($output =~ /^LoadState=masked$/) {
        return 1;
    }
    return 0;
}

=head2 ->adjust

Adjust the service startup state and running state according to its
configuration, status prop and the owning package installation status.

The output parameter $action is set to 'start' or 'stop' if the
service is actually started or stopped.

Parameters:
    $action string by ref (OUT)

Returns a boolean value: success/failure

=cut
sub adjust
{
    my $self = shift;
    my $action = shift;
    my $errors = 0;

    if($self->is_configured() && ! $self->is_masked() ) {
	my $staticState = $self->is_enabled() && $self->is_owned();
	system(sprintf('systemctl -q %s "%s" 2>/dev/null', ($staticState ? 'enable' : 'disable'), $self->{'serviceName'}));
	if($staticState != $self->is_running()) {
	    if(system('systemctl', $staticState ? 'start' : 'stop', $self->{'serviceName'}) == 0) {
	        $$action = $staticState ? 'start' : 'stop';
	    } else {
		$errors += 1;
	    }
	}
    }

    return $errors == 0;
}

=head2 ->get_name

Return the service name

=cut
sub get_name
{
    my $self = shift;
    return $self->{'serviceName'};
}

1;
