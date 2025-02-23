#!/usr/bin/perl -w

# Copyright 2001-2019, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.21 - 14th November 2019

use strict;

require 5.005;

use lib "/var/www/Gedcom/lib";

use CGI qw(:cgi :html);

use Gedcom::CGI 1.21;

my $op = param("op");

eval { Gedcom::CGI->$op() };

if (my $error = $@) {
    print header,
          start_html,
          h1("Gedcom error"),
          "Unable to run $op.",
          pre($error),
          end_html;
}

__END__

=head1 NAME

main.cgi

Version 1.21 - 14th November 2019

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
