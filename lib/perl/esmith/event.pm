#
# Copyright (C) 1999-2005 Mitel Networks Corporation
# http://contribs.org 
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

package esmith::event;

use strict;
use Exporter;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use esmith::Logger;
use File::Basename;
use NethServer::TrackerClient;
use JSON;

=pod

=head1 NAME

esmith::event - Routines for handling e-smith events

=head1 SYNOPSIS

    use esmith::event;

    my $exitcode = event_signal($event, @args);

=head1 DESCRIPTION

=cut

our $VERSION = sprintf '%d.%03d', q$Revision: 1.16 $ =~ /: (\d+).(\d+)/;
our @ISA         = qw(Exporter);
our @EXPORT      = qw(event_signal set_json_log);

our @EXPORT_OK   = ();
our %EXPORT_TAGS = ();
our $return_value = undef;
our $json = 0;

tie *LOG, 'esmith::Logger', 'esmith::event';

sub set_json_log
{
    $json = shift;
}

sub _log_json
{
    my $hash = shift;
    if ($json) {
        $hash->{'pid'} = $$;
        print encode_json($hash)."\n";
    }
}

sub event_signal
{
    my ($event, @args) = @_;
    if ($event eq "actions")
    {
        warn("'actions' is not a valid event name.\n");
        return;
    }

    my $isSuccess = 1; # 1=TRUE
    my $events = "/etc/e-smith/events";
    my $handlerDir = "$events/$event";
    my $actionsDir = "$events/actions";

    # Declare a subtask for each handler (action)
    my $tracker = NethServer::TrackerClient->new();
    my %tasks = ();

    #------------------------------------------------------------
    # get event handler filenames
    #------------------------------------------------------------
    opendir (DIR, $handlerDir)
        || die "Can't open directory $handlerDir\n";

    # Create a hash of handlers (ignore directories and
    # non-executable), with value of basename(handler)
    my %handlers = ();
    foreach (grep {! -d "$handlerDir/$_"} readdir (DIR)) {
	my $handler = "$handlerDir/$_";
	if(-x $handler) {
	    $handlers{$handler} = $_;	   
	} else {
	    print LOG "Skipping non-executable event-handler $_";
	    next;
	}
    }
    closedir (DIR);

    # Add generic handlers to list, if their metadata directories
    # exist
    $handlers{"$actionsDir/generic_template_expand"} = "S05generic_template_expand"
	if ( -d "$handlerDir/templates2expand");
    $handlers{"$actionsDir/adjust-services"} = "S90adjust-services"
	if ( -d "$handlerDir/services2adjust");

    my @handlerList = sort { $handlers{$a} cmp $handlers{$b} } keys %handlers;

    foreach my $handler (@handlerList) {
	$tasks{$handler} = $tracker->declare_task(basename $handler);
    }

    my $steps = scalar @handlerList;
    #------------------------------------------------------------
    # Execute all handlers, sending any output to the system log.
    #
    # Relevant messages are tracked by NethServer::TrackerClient
    #------------------------------------------------------------
    print LOG "Event: $event @args";
    _log_json({"event" => $event, "args" => join(",",@args), "steps" =>  $steps});

    #------------------------------------------------------------
    # Run handlers, logging all output.
    #------------------------------------------------------------
    my $i = 1;
    foreach my $handler (@handlerList) {
	#print LOG "Running event handler " . $handlers{$handler};
        _log_json({"event" => $event, "action" => $handlers{$handler}, "state" => "running", "step" => $i});
        my $startTime = [gettimeofday];
	my $status = _mysystem(\*LOG, $handler, $event, \%tasks, @args);
	if($status != 0) {
	    $isSuccess = 0; # 0=FALSE. if any handler fails, the
			    # entire event fails
	}
	my $endTime = [gettimeofday];
	my $elapsedTime = tv_interval($startTime, $endTime);
	my $log = "Action: $handler ";
	if($status) {
	    if($status & 0xFF) {
		$log .= 'FAILED: ' . ($status & 0xFF);
	    } else {
		$log .= 'FAILED: ' . ($status >> 8);
	    }
	} else {
            $log .= 'SUCCESS';
        }
        $log .= " [$elapsedTime]";
	print LOG $log;
        _log_json({"event" => $event, "time" => $elapsedTime, "action" => $handlers{$handler}, "exit" => $status, "state" => "done", "step" => $i, "progress" => sprintf("%.2f", $i/$steps)});

	$tracker->set_task_done($tasks{$handler}, "", $status);
        $i++;
    }

    if (!$isSuccess) {
        print LOG "Event: $event FAILED";
        _log_json({ "event" => $event, "status" => "failed"});
    } else {
        print LOG "Event: $event SUCCESS";
        _log_json({"event" => $event, "status" => "success"});
    }
    return $isSuccess;
}

sub _mysystem
{
    my ($logger, $filename, $event, $tasks, @args) = @_;

    my $pid = open(PIPE, "-|");
    die "Failed to fork: $!\n" unless defined $pid;

    if ($pid) {
        # Parent
        while (my $line = <PIPE>) {
            print $logger $line;
        }
    } else {
        # Child
        open(STDERR, ">&STDOUT");
	$ENV{'PTRACK_TASKID'} = $tasks->{$filename};
        exec($filename, $event, @args);
    }
    close(PIPE);
    return $?;
}


1;
