#
# Copyright (C) 2014 Nethesis S.r.l.
# http://www.nethesis.it - support@nethesis.it
#
# Original work from: 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package esmith::I18N;

use strict;

use POSIX qw();
use Locale::gettext;

=pod

=head1 NAME

esmith::I18N - Internationalization utilities Mitel Network SME Server

=head1 VERSION

This file documents C<esmith::I18N> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::I18N;

    my $i18n = new esmith::I18N;

=head1 DESCRIPTION

This module provides general internationalization and localisation
utilities for developers of the Mitel Networks SME Server.

=begin testing

use I18N::LangTags qw(is_language_tag locale2language_tag language_tag2locale);
use_ok('esmith::I18N');

=end testing

=head1 GENERAL UTILITIES

=cut

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;

    my %args = @_;

    return $self;
}

=head2 setLocale()

Configure the locale for gettext() for the supplied text domain.

The method takes two arguments, the text domain, and an optional argument
which can be either a language tag or a locale.

=cut

sub setLocale()
{
    my ($self, $text_domain) = @_;

    POSIX::setlocale(POSIX::LC_MESSAGES, "");
    POSIX::setlocale(POSIX::LC_MESSAGES, "");
    POSIX::setlocale(POSIX::LC_ALL, "");
    POSIX::setlocale(POSIX::LC_ALL, "");

    bindtextdomain ($text_domain, "/usr/share/locale");
    textdomain ($text_domain);
}


1;
