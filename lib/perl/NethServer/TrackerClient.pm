#
# NethServer TrackerClient
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

package NethServer::TrackerClient;

use JSON;
use IO::Socket;

=head1 NAME

NethServer::TrackerClient -- Task progress tracker client

=head1 DESCRIPTION

This class keeps a connection to the ptrack server, that collects the
progress status of a hierarchy of tasks.

If you plan to execute a subprocess that represents a subtask, invoke
the declare_task() method, to obtain a new task id, then set the
environment variable PTRACK_TASKID for the subprocess.

=head1 Methods

=over 4

=item B<new>

  parentId (integer) optional -- The default parent task id
  socket (IO::Socket) optional -- An already connected to the server

Creates a class instance. It accepts two optional arguments.

If parentId is undef, the value is read from the environment variable
PTRACK_TASKID. If this is missing, a value int(0) is assumed,
corresponding to the root task, declared by ptrack itself.

If the socket is undef, a unix socket is opened from the filesystem
path pointed by the environment variable PTRACK_SOCKETPATH. 

The socket is closed when the object is destroyed.

=cut
sub new
{
    my $class = shift;
    my $parentId = shift;
    my $socket = shift;

    if( ! defined($parentId)) {
	# Try to import from environment:
	$parentId = defined $ENV{'PTRACK_TASKID'} ? $ENV{'PTRACK_TASKID'} : 0;
    }

    if($parentId !~  m/^\d+$/) {
	$parentId = 0; # Default 0 value if non-numeric at this point
    }

    my $self = {
	'debug' => 0,
	'socket' => ($socket || __createSocket()),
	'parentId' => int($parentId), # Ensure an integer type
	'codes' => {
	    TY_DECLARE  => 0x01,
	    TY_DONE     => 0x02,
	    TY_QUERY    => 0x03,
	    TY_PROGRESS => 0x04,
	    TY_ERROR    => 0x40,
	    TY_RESPONSE => 0x80,
	}
    };

    bless $self, $class;

    return $self;
}

sub __createSocket()
{
    my $path = $ENV{'PTRACK_SOCKETPATH'};
    if( ! $path || ! -S $path) {
	return undef;
    }
    my $socket = IO::Socket::UNIX->new($path);
    return $socket;
}


=item B<declare_task>

  title (string) optional
  weight (float) optional, defaults to 1.0
  parentId (integer) optional defaults to parentId set from constructor

Returns the declared task identifier (integer).  

=cut
sub declare_task()
{
    my $self = shift;
    my $title = shift;
    my $weight = shift;
    my $parentId = shift;

    return $self->__send(
	$self->{codes}->{TY_DECLARE}, [
	    defined $parentId ? int($parentId) :  $self->{parentId}, 
	    $weight || 1.0, 
	    $title
	]);
}

=item B<set_task_done>

  taskId (integer)
  message (string)
  code (integer)

=cut
sub set_task_done()
{
    my $self = shift;
    my $taskId = shift;
    my $message = shift;
    my $code = shift;

    return $self->__send(
	$self->{codes}->{TY_DONE}, [
	    int($taskId), 
	    $message, 
	    defined $code ? int($code) : undef
	]);
}

=item B<set_task_progress>

  taskId (integer)
  progress (float)
  message (string)
  code (integer)

=cut
sub set_task_progress()
{
    my $self = shift;
    my $taskId = shift;
    my $progress = shift;
    my $message = shift;
    my $code = shift;
    return $self->__send(
	$self->{codes}->{TY_PROGRESS}, [
	    int($taskId), 
	    $progress || 0.0, 
	    $message, 
	    defined $code ? int($code) : undef
	]);
}

=item B<query>
 
  subject (string) defaults to "progress"

=cut
sub query()
{
    my $self = shift;
    my $subject = shift;
    return $self->__send(
	$self->{codes}->{TY_QUERY}, [
	    $subject,
	]);
}

=item B<get_progress>

DEPRECATED use query

=cut
sub get_progress()
{
    my $self = shift;
    return $self->query('progress');
}

sub __send
{
    use bytes;
    my $self = shift;
    my $type = shift;
    my $json_opts = {utf8 => 0, pretty => 0, allow_nonref => 1};
    my $payload = to_json($_[0], $json_opts);

    if( ! $self->{socket}) {
	return 0;
    }

    my $data = pack('Cn', $type, length($payload)) . $payload;

    $self->{debug} && warn sprintf("[DEBUG] sending 0x%02x len=%d %s\n", $type, length($payload), $payload);

    $self->{socket}->write($data);
    
    my $buf;
    $self->{socket}->read($buf, 3);

    my ($message_type, $message_length) = unpack('Cn', $buf);

    if($message_type & $self->{codes}->{TY_ERROR}) {
	$self->{debug} && warn "[ERROR] from ptrack server\n";
    }
    
    $self->{debug} && warn sprintf("[DEBUG] receiving 0x%2x len=%d\n", $message_type, $message_length);

    $self->{socket}->read($buf, $message_length);
    return from_json($buf, $json_opts);
}

sub DESTROY {
    my $self = shift; 
    if($self->{socket}) {
	$self->{socket}->close();
    }
}

=back
=cut
1;
