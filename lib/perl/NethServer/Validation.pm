#
# Copyright (C) 2012 Nethesis S.r.l.
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

package NethServer::Validation;

use strict;
use constant DEBUG => 0;
use File::Basename;

=pod

=head1 NethServer::Validation

Routines for handling system-wide validators

=head2 Example

    use NethServer::Validation;

    my $exitcode = NethServer::Validation::validate($validator, @args);

=head1 validate()

Searches for all validator scripts inside the validator directory,
'/etc/e-smith/validators' then executes them.

A successful validation occurs when all scripts return 0 (success
validation) or at least one script returns 2 (sufficient valid
condition). Otherwise validation fails.

Each script in the validator directory must return one of these exit
values:

  0: successful validation

  1: validation failed (generic)

  2: sufficient validation (successful)

  3..255: failed with specific reason

When a script returns 2 (sufficient validation) no further script will
be processed and the validate() is successful.

Scripts are not supposed to generate error messages under normal
conditions, so we do not provide a mechanism for validator handlers to
signal errors to the user. Errors can only be written to the log file.

=head2 Return value

The validate() function returns 0 on failure, 1 on success.

=cut

sub validate
{
    my ($validator, @args) = @_;

    my $validators = "/etc/e-smith/validators";
    my $handlerDir = "$validators/$validator";

    #------------------------------------------------------------
    # get validator handler filenames
    #------------------------------------------------------------
    opendir (DIR, $handlerDir)
        || die "Can't open directory $handlerDir\n";

    # Create a hash of handlers (ignore directories),
    # with value of basename(handler)
    my %handlers = ();
    foreach (grep {! -d "$handlerDir/$_"} readdir (DIR))
    {
	$handlers{"$handlerDir/$_"} = $_;
    }

    closedir (DIR);

    #------------------------------------------------------------
    # Validator handlers are not supposed to generate error messages
    # under normal conditions, so we do not provide a mechanism
    # for validator handlers to signal errors to the user. Errors can
    # only be written to the log file.
    #------------------------------------------------------------
    debug("validate(): processing validator $validator @args");

    #------------------------------------------------------------
    # Run handlers, logging all output.
    #------------------------------------------------------------

    # assume success
    my $exitcode = 0;

    foreach my $filename
	(sort { $handlers{$a} cmp $handlers{$b} } keys %handlers)
    {
        my $handler = basename $filename;

        my $status = 0;
        if (-x $filename)
        {
            debug("validate(): running handler `$filename`");

            system($filename, @args);
            $status = $? >> 8; # real exit value is shifted right by eight

            if ($status == 0) # VALID
            {
		debug("validate(): VALID $filename");
		next;
            }
	    elsif ($status == 2) # SUFFICIENT
            {
                debug("validate(): SUFFICIENT $filename - SUCCESS");
                return 1; # SUCCESS
            }
	    else 
	    {
                # if any handler fails, the entire validator fails
                debug("validate(): INVALID $filename $status - FAILED");	       

		if(-l $filename) {
		    $filename = readlink $filename;
		}	       		

		print join(',', $validator, basename($filename), $status) . "\n";
                return 0; # FAILED
	    }
        }
        else
        {
            debug("validate(): Skipping non-executable validator handler `$filename`");
	    next;
        }

    }

    debug("validate: SUCCESS");
    return 1; # SUCCESS -DEFAULT
}

sub debug
{
    my $msg = shift;
    warn "[DEBUG] $msg\n" if DEBUG;
}

1;
