# Copyright 2003-2019, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Comparison;

use vars qw($VERSION $Indent);
$VERSION = "1.21";
$Indent  = 0;

BEGIN { eval "use Date::Manip" }             # We'll use this if it is available

use Gedcom::Item 1.21;

my %cache;

sub new {
    my $class     = shift;
    my ($r1, $r2) = @_;
    $r1           = "" unless defined $r1;
    $r2           = "" unless defined $r2;

    my $key ="$r1--$r2";

    return $cache{$key} if exists $cache{$key};

    my $self = {
        record1 => $r1,
        record2 => $r2,
    };

    bless $self, $class;

    if (!%cache && !$INC{"Date/Manip.pm"}) {
        warn "Date::Manip.pm may be required to accurately compare dates\n";
    }

    $cache{$key} = $self->_compare
}


sub _compare {
    my $self = shift;

    $self->{$_} = [] for qw( identical conflict only1 only2 );

    my $r1 = $self->{record1};
    my $r2 = $self->{record2};

    my ($v1, $v2) = ($r1->{value}, $r2->{value});

    # The values match if neither record has a value, or if both do and
    # they are the same.

    if (0) {
        $self->{value_match} = !(defined $v1 ^ defined $v2);
        $self->{value_match} &&= $v1 eq $v2 if defined $v1;
    } else {
        if ($r1->tag eq "DATE") {
            my $err;
            my $d = DateCalc($v1, $v2, \$err, 1);
            # print "**** [$v1] [$v2] $d\n";
            my @d = split ":", $d;
            $self->{value_match} = grep (!($_ + 0), @d) / @d;
        } else {
            $self->{value_match} = !(defined $v1 ^ defined $v2);
            $self->{value_match} &&= $v1 eq $v2 if defined $v1;
        }
    }

    my @r1 = $r1 && UNIVERSAL::isa($r1, "Gedcom::Item") ? $r1->items : ();
    my @r2 = $r2 && UNIVERSAL::isa($r2, "Gedcom::Item") ? $r2->items : ();

    TAG1:
    for my $i1 (@r1) {
        my $tag       = $i1->tag;
        my @match     = (-1, -1);
        for my $i2 (0 .. $#r2) {
            next unless $r2[$i2]->tag eq $tag;
            my $comp = Gedcom::Comparison->new($i1, $r2[$i2]);  # TODO memoise
            my $m    = $comp->match;
            @match   = ($i2, $m, $comp) if $m > $match[1];
        }

        if ($match[2]) {
            push @{$self->{$match[2]->identical ? "identical" : "conflict"}},
            $match[2];
            splice @r2, $match[0], 1;
            next
        }

        push @{$self->{only1}}, $i1;
    }

    $self->{only2} = \@r2;

    $self
}


sub identical {
    my $self = shift;
    $self->match == 100
}

sub match {
    my $self = shift;
    $self->{match} =
        100 *
        ($self->{value_match} + @{$self->{identical}}) /
        (1                    + @{$self->{identical}}
                            + @{$self->{conflict}}
                            + @{$self->{only1}}
                            + @{$self->{only2}})
        unless exists $self->{match};
    $self->{match}
}

sub print {
    my $self = shift;

    local $Indent = $Indent + 1;
    my $i = "  " x ($Indent - 1);

    print $self->identical ? $i : "${i}not ";
    print "identical\n";

    printf "${i}match:       %5.2f%%\n", $self->match;
    printf "${i}value match: %d\n",      $self->{value_match};
    printf "${i}identical:   %d\n",      scalar @{$self->{identical}};
    printf "${i}conflict:    %d\n",      scalar @{$self->{conflict}};
    printf "${i}only1:       %d\n",      scalar @{$self->{only1}};
    printf "${i}only2:       %d\n",      scalar @{$self->{only2}};

    print "${i}record 1:\n";
    $self->{record1}->print;
    print "${i}record 2:\n";
    $self->{record2}->print;

    print "${i}conflicts:\n";
    my $c;
    print($i, ++$c, ":\n"), $_->print for @{$self->{conflict}};
}

1;

__END__

=head1 NAME

Gedcom::Comparison - a module to compare Gedcom records

Version 1.21 - 14th November 2019

=head1 SYNOPSIS

  use Gedcom::Comparison;

=head1 DESCRIPTION

=head1 METHODS

=cut
