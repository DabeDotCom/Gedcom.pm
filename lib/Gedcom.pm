# Copyright 1998-2019, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom;

use Carp;
use Data::Dumper;
use FileHandle;

BEGIN { eval "use Text::Soundex" }           # We'll use this if it is available

use vars qw($VERSION $AUTOLOAD %Funcs);

my $Tags;
my %Top_tag_order;

BEGIN {
    $VERSION = "1.21";

    $Tags = {
        ABBR => "Abbreviation",
        ADDR => "Address",
        ADOP => "Adoption",
        ADR1 => "Address1",
        ADR2 => "Address2",
        AFN  => "Afn",
        AGE  => "Age",
        AGNC => "Agency",
        ALIA => "Alias",
        ANCE => "Ancestors",
        ANCI => "Ances Interest",
        ANUL => "Annulment",
        ASSO => "Associates",
        AUTH => "Author",
        BAPL => "Baptism-LDS",
        BAPM => "Baptism",
        BARM => "Bar Mitzvah",
        BASM => "Bas Mitzvah",
        BIRT => "Birth",
        BLES => "Blessing",
        BLOB => "Binary Object",
        BURI => "Burial",
        CALN => "Call Number",
        CAST => "Caste",
        CAUS => "Cause",
        CENS => "Census",
        CHAN => "Change",
        CHAR => "Character",
        CHIL => "Child",
        CHR  => "Christening",
        CHRA => "Adult Christening",
        CITY => "City",
        CONC => "Concatenation",
        CONF => "Confirmation",
        CONL => "Confirmation L",
        CONT => "Continued",
        COPR => "Copyright",
        CORP => "Corporate",
        CREM => "Cremation",
        CTRY => "Country",
        DATA => "Data",
        DATE => "Date",
        DEAT => "Death",
        DESC => "Descendants",
        DESI => "Descendant Int",
        DEST => "Destination",
        DIV  => "Divorce",
        DIVF => "Divorce Filed",
        DSCR => "Phy Description",
        EDUC => "Education",
        EMIG => "Emigration",
        ENDL => "Endowment",
        ENGA => "Engagement",
        EVEN => "Event",
        FAM  => "Family",
        FAMC => "Family Child",
        FAMF => "Family File",
        FAMS => "Family Spouse",
        FCOM => "First Communion",
        FILE => "File",
        FORM => "Format",
        GEDC => "Gedcom",
        GIVN => "Given Name",
        GRAD => "Graduation",
        HEAD => "Header",
        HUSB => "Husband",
        IDNO => "Ident Number",
        IMMI => "Immigration",
        INDI => "Individual",
        LANG => "Language",
        LEGA => "Legatee",
        MARB => "Marriage Bann",
        MARC => "Marr Contract",
        MARL => "Marr License",
        MARR => "Marriage",
        MARS => "Marr Settlement",
        MEDI => "Media",
        NAME => "Name",
        NATI => "Nationality",
        NATU => "Naturalization",
        NCHI => "Children_count",
        NICK => "Nickname",
        NMR  => "Marriage_count",
        NOTE => "Note",
        NPFX => "Name_prefix",
        NSFX => "Name_suffix",
        OBJE => "Object",
        OCCU => "Occupation",
        ORDI => "Ordinance",
        ORDN => "Ordination",
        PAGE => "Page",
        PEDI => "Pedigree",
        PHON => "Phone",
        PLAC => "Place",
        POST => "Postal_code",
        PROB => "Probate",
        PROP => "Property",
        PUBL => "Publication",
        QUAY => "Quality Of Data",
        REFN => "Reference",
        RELA => "Relationship",
        RELI => "Religion",
        REPO => "Repository",
        RESI => "Residence",
        RESN => "Restriction",
        RETI => "Retirement",
        RFN  => "Rec File Number",
        RIN  => "Rec Id Number",
        ROLE => "Role",
        SEX  => "Sex",
        SLGC => "Sealing Child",
        SLGS => "Sealing Spouse",
        SOUR => "Source",
        SPFX => "Surn Prefix",
        SSN  => "Soc Sec Number",
        STAE => "State",
        STAT => "Status",
        SUBM => "Submitter",
        SUBN => "Submission",
        SURN => "Surname",
        TEMP => "Temple",
        TEXT => "Text",
        TIME => "Time",
        TITL => "Title",
        TRLR => "Trailer",
        TYPE => "Type",
        VERS => "Version",
        WIFE => "Wife",
        WILL => "Will",
    };

    %Top_tag_order = (
        HEAD => 1,
        SUBM => 2,
        INDI => 3,
        FAM  => 4,
        NOTE => 5,
        REPO => 6,
        SOUR => 7,
        TRLR => 8,
    );

    while (my ($tag, $name) = each (%$Tags)) {
        $Funcs{$tag} = $Funcs{lc $tag} = $tag;
        if ($name) {
            $name =~ s/ /_/g;
            $Funcs{lc $name} = $tag;
        }
    }
}

sub DESTROY {}

sub AUTOLOAD {
    my ($self) = @_;  # don't change @_ because of the goto
    my $func = $AUTOLOAD;
    # print "autoloading $func\n";
    $func =~ s/^.*:://;
    my $tag;
    croak "Undefined subroutine $func called"
    if $func !~ /^(add|get)_(.*)$/ ||
    !($tag = $Funcs{lc $2}) ||
    !exists $Top_tag_order{$tag};
    no strict "refs";
    if ($1 eq "add") {
        *$func = sub {
            my $self = shift;
            my ($arg, $val) = @_;
            my $xref;
            if (ref $arg) {
                $xref = $arg->{xref};
            } else {
                $val = $arg;
            }
            my $record = $self->add_record(tag => $tag, val => $val);
            if (defined $val && $tag eq "NOTE") {
                $record->{value} = $val;
            }
            $xref = $tag eq "SUBM" ? "SUBM" : substr $tag, 0, 1
            unless defined $xref;
            unless ($tag =~ /^(HEAD|TRLR)$/) {
                croak "Invalid xref $xref requested in $func"
                unless $xref =~ /^[^\W\d_]+(\d*)$/;
                $xref = $self->next_xref($xref) unless length $1;
                $record->{xref} = $xref;
                $self->{xrefs}{$xref} = $record;
            }
            $record
        };
    } else {
        *$func = sub {
            my $self   = shift;
            my ($xref) = @_;
            my $nxr    = !defined $xref;
            my @a = grep { $_->{tag} eq $tag && ($nxr || $_->{xref} eq $xref) }
                         @{$self->{record}->_items};
            wantarray ? @a : $a[0]
        };
    }
    goto &$func
}

use Gedcom::Grammar    1.21;
use Gedcom::Individual 1.21;
use Gedcom::Family     1.21;
use Gedcom::Event      1.21;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    @_ = (gedcom_file => @_) if @_ == 1;
    my $self = {
        records   => [],
        tags      => $Tags,
        read_only => 0,
        types     => {},
        xrefs     => {},
        encoding  => "ansel",
        @_
    };

    # TODO - find a way to do this nicely for different grammars
    $self->{types}{INDI} = "Individual";
    $self->{types}{FAM}  = "Family";
    $self->{types}{$_}   = "Event" for qw(
        ADOP ANUL BAPM BARM BASM BIRT BLES BURI CAST CENS CENS CHR CHRA CONF
        CREM DEAT DIV DIVF DSCR EDUC EMIG ENGA EVEN EVEN FCOM GRAD IDNO IMMI
        MARB MARC MARL MARR MARS NATI NATU NCHI NMR OCCU ORDN PROB PROP RELI
        RESI RETI SSN WILL
    );
    bless $self, $class;

    # first read in the grammar
    my $grammar;
    if (defined $self->{grammar_file}) {
        my $version;
        if (defined $self->{grammar_version}) {
            $version = $self->{grammar_version};
        } else {
            ($version) = $self->{grammar_file} =~ /(\d+(\.\d+)*)/;
        }
        die "version must be a GEDCOM version number\n" unless $version;
        return undef unless
        $grammar = Gedcom::Grammar->new(
            file     => $self->{grammar_file},
            version  => $version,
            callback => $self->{callback}
        );
    } else {
        $self->{grammar_version} = 5.5 unless defined $self->{grammar_version};
        (my $v = $self->{grammar_version}) =~ tr/./_/;
        my $g = "Gedcom::Grammar_$v";
        eval "use $g $VERSION";
        die $@ if $@;
        no strict "refs";
        return undef unless $grammar = ${$g . "::grammar"};
    }
    my @c = ($self->{grammar} = $grammar);
    while (@c) {
        @c = map { $_->{top} = $grammar; @{$_->{items}} } @c;
    }

    # now read in or create the GEDCOM file
    return undef unless
    my $r = $self->{record} = Gedcom::Record->new(
        defined $self->{gedcom_file} ? (file => $self->{gedcom_file}) : (),
        line     => 0,
        tag      => "GEDCOM",
        grammar  => $grammar->structure("GEDCOM"),
        gedcom   => $self,
        callback => $self->{callback},
    );

    unless (defined $self->{gedcom_file}) {

    # Add the required elements, unless they are already there.

        unless ($r->get_record("head")) {
            my $me = "Unknown user";
            my $login = $me;
            if ($login = getlogin || (getpwuid($<))[0] ||
                         $ENV{USER} || $ENV{LOGIN}) {
                my $name;
                eval { $name = (getpwnam($login))[6] };
                $me = $name || $login;
            }
            my $date = localtime;

            my ($l0, $l1, $l2, $l3);
            $l0 = $self->add_header;
                $l1 = $l0->add("SOUR", "Gedcom.pm");
                $l1->add("NAME", "Gedcom.pm");
                $l1->add("VERS", $VERSION);
                    $l2 = $l1->add("CORP", "Paul Johnson");
                    $l2->add("ADDR", "http://www.pjcj.net");
                    $l2 = $l1->add("DATA");
                        $l3 = $l2->add(
                            "COPR",
                            'Copyright 1998-2019, Paul Johnson (paul@pjcj.net)'
                        );
                $l1 = $l0->add("NOTE", "");
                for (split /\n/, <<'EOH')
This output was generated by Gedcom.pm.
Gedcom.pm is Copyright 1998-2019, Paul Johnson (paul@pjcj.net)
Version 1.21 - 14th November 2019

Gedcom.pm is free.  It is licensed under the same terms as Perl itself.

The latest version of Gedcom.pm should be available from my homepage:
http://www.pjcj.net
EOH
                {
                    $l1->add("CONT", $_);
                };
                $l1 = $l0->add("GEDC");
                $l1->add("VERS", $self->{grammar}{version});
                $l1->add("FORM", "LINEAGE-LINKED");
            $l0->add("DATE", $date);
            $l0->add("CHAR", uc ($self->{encoding} || "ansel"));
            my $s = $r->get_record("subm");
            unless ($s) {
                $s = $self->add_submitter;
                $s->add("NAME", $me);
            }
            $l0->add("SUBM", $s->xref);
        }

        $self->add_trailer unless $r->get_record("trlr");
    }

    $self->collect_xrefs;

    $self
}

sub set_encoding {
    my $self = shift;
    ($self->{encoding}) = @_;
}

sub write {
    my $self  = shift;
    my $file  = shift or die "No filename specified";
    my $flush = shift;
    $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
    binmode $self->{fh}, ":encoding(UTF-8)"
        if $self->{encoding} eq "utf-8" && $] >= 5.8;
    $self->{record}->write($self->{fh}, -1, $flush);
    $self->{fh}->close or die "Can't close $file: $!";
}

sub write_xml {
    my $self = shift;
    my $file = shift or die "No filename specified";
    $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
    binmode $self->{fh}, ":encoding(UTF-8)"
        if $self->{encoding} eq "utf-8" && $] >= 5.8;
    $self->{fh}->print(<<'EOH');
<?xml version="1.0" encoding="utf-8"?>

<!--

This output was generated by Gedcom.pm.
Gedcom.pm is Copyright 1998-2019, Paul Johnson (paul@pjcj.net)
Version 1.21 - 14th November 2019

Gedcom.pm is free.  It is licensed under the same terms as Perl itself.

The latest version of Gedcom.pm should be available from my homepage:
http://www.pjcj.net

EOH
    $self->{fh}->print("Generated on " . localtime() . "\n\n-->\n\n");
    $self->{record}->write_xml($self->{fh});
    $self->{fh}->close or die "Can't close $file: $!";
}

sub add_record {
    my $self = shift;
    $self->{record}->add_record(@_);
}

sub collect_xrefs {
    my $self = shift;
    my ($callback) = @_;
    $self->{xrefs} = {};
    $self->{record}->collect_xrefs($callback);
}

sub resolve_xref {
    my $self = shift;;
    my ($x) = @_;
    my $xref;
    $xref = $self->{xrefs}{$x =~ /^\@(.+)\@$/ ? $1 : $x} if defined $x;
    $xref
}

sub resolve_xrefs {
    my $self = shift;
    my ($callback) = @_;
    $self->{record}->resolve_xrefs($callback);
}

sub unresolve_xrefs {
    my $self = shift;
    my ($callback) = @_;
    $self->{record}->unresolve_xrefs($callback);
}

sub validate {
    my $self = shift;
    my ($callback) = @_;
    $self->{validate_callback} = $callback;
    my $ok = $self->{record}->validate_syntax;
    for my $item (@{$self->{record}->_items}) {
        $ok = 0 unless $item->validate_semantics;
    }
    $ok
}

sub normalise_dates {
    my $self = shift;
    $self->{record}->normalise_dates(@_);
}

sub renumber {
    my $self = shift;
    my (%args) = @_;
    $self->resolve_xrefs;

    # initially, renumber any records passed in
    for my $xref (@{$args{xrefs}}) {
        $self->{xrefs}{$xref}->renumber(\%args, 1)
            if exists $self->{xrefs}{$xref};
    }

    # now, renumber any records left over
    $_->renumber(\%args, 1) for @{$self->{record}->_items};

    # actually change the xref
    for my $record (@{$self->{record}->_items}) {
        $record->{xref} = delete $record->{new_xref};
        delete $record->{recursed}
    }

    # and update the xrefs
    $self->collect_xrefs;

    %args
}

sub sort_sub {
    # subroutine to sort on tag order first, and then on xref

    my $t = sub {
        my ($r) = @_;
        return -2 unless defined $r->{tag};
        exists $Top_tag_order{$r->{tag}} ? $Top_tag_order{$r->{tag}} : -1
    };

    my $x = sub {
        my ($r) = @_;
        return -2 unless defined $r->{xref};
        $r->{xref} =~ /(\d+)/;
        defined $1 ? $1 : -1
    };

    sub {
        $t->($a) <=> $t->($b)
        ||
        $x->($a) <=> $x->($b)
    }
}

sub order {
    my $self     = shift;
    my $sort_sub = shift || sort_sub;   # use default sort unless one passed in
    @{$self->{record}{items}} = sort $sort_sub @{$self->{record}->_items}
}

sub items {
    my $self = shift;
    @{$self->{record}->_items}
}

sub heads        { grep $_->tag eq "HEAD",           shift->items }
sub submitters   { grep $_->tag eq "SUBM",           shift->items }
sub individuals  { grep ref eq "Gedcom::Individual", shift->items }
sub families     { grep ref eq "Gedcom::Family",     shift->items }
sub notes        { grep $_->tag eq "NOTE",           shift->items }
sub repositories { grep $_->tag eq "REPO",           shift->items }
sub sources      { grep $_->tag eq "SOUR",           shift->items }
sub trailers     { grep $_->tag eq "TRLR",           shift->items }

sub get_individual {
    my $self = shift;
    my $name = "@_";
    my $all  = wantarray;
    my @i;

    my $i = $self->resolve_xref($name) || $self->resolve_xref(uc $name);
    if ($i) {
        return $i unless $all;
        push @i, $i;
    }

    # search for the name in the specified order
    my $ordered = sub {
        my ($n, @ind) = @_;
        map { $_->[1] } grep { $_ && $_->[0] =~ $n } @ind
    };

    # search for the name in any order
    my $unordered = sub {
        my ($names, $t, @ind) = @_;
        map { $_->[1] } grep {
            my $i = $_->[0];
            my $r = 1;
            for my $n (@$names) {
                # remove matches as they are found
                # we don't want to match the same name twice
                last unless $r = $i =~ s/$n->[$t]//;
            }
            $r
        }
        @ind;
    };

    # look for various matches in decreasing order of exactitude
    my @individuals = $self->individuals;

    # Store the name with the individual to avoid continually recalculating it.
    # This is a bit like a Schwartzian transform, with a grep instead of a sort.
    my @ind =
        map [do { my $n = $_->tag_value("NAME"); defined $n ? $n : "" } => $_],
        @individuals;

    for my $n (map { qr/^$_$/, qr/\b$_\b/, $_ } map { $_, qr/$_/i } qr/\Q$name/)
    {
        push @i, $ordered->($n, @ind);
        return $i[0] if !$all && @i;
    }

    # create an array with one element per name
    # each element is an array of REs in decreasing order of exactitude
    my @names = map [ map { qr/\b$_\b/, $_ } map { qr/$_/, qr/$_/i } "\Q$_" ],
                split / /, $name;
    for my $t (0 .. $#{$names[0]}) {
        push @i, $unordered->(\@names, $t, @ind);
        return $i[0] if !$all && @i;
    }

    # check soundex
    my @sdx = map { my $s = $_->soundex; $s ? [ $s => $_ ] : () } @individuals;

    my $soundex = soundex($name);
    for my $n ( map { qr/$_/ } $name, ($soundex || ()) ) {
        push @i, $ordered->($n, @sdx);
        return $i[0] if !$all && @i;
    }

    return undef unless $all;

    my @s;
    my %s;
    for (@i) {
        unless (exists $s{$_->{xref}}) {
            push @s, $_;
            $s{$_->{xref}}++;
        }
    }

    @s
}

sub next_xref {
    my $self = shift;
    my ($type) = @_;
    my $re = qr/^$type(\d+)$/;
    my $last = 0;
    for my $c (@{$self->{record}->_items}) {
        $last = $1 if defined $c->{xref} and $c->{xref} =~ /$re/ and $1 > $last;
    }
    $type . ++$last
}

sub top_tag {
    my $self = shift;
    my ($tag) = @_;
    $Top_tag_order{$tag}
}

"
But take your time, think a lot
Think of everything you've got
For you will still be here tomorrow
But your dreams may not
"

__END__

=head1 NAME

Gedcom - a module to manipulate GEDCOM genealogy files

Version 1.21 - 14th November 2019

=head1 SYNOPSIS

  use Gedcom;

  my $ged = Gedcom->new;
  my $ged = Gedcom->new($gedcom_file);
  my $ged = Gedcom->new(grammar_version => "5.5.1",
                        gedcom_file     => $gedcom_file,
                        read_only       => 1,
                        callback        => $cb);
  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);

  return unless $ged->validate;
  my $xref = $self->resolve_xref($value);
  $ged->resolve_xrefs;
  $ged->unresolve_xrefs;
  $ged->normalise_dates;
  my %xrefs = $ged->renumber;
  $ged->order;
  $ged->set_encoding("utf-8");
  $ged->write($new_gedcom_file, $flush);
  $ged->write_xml($new_xml_file);
  my @individuals = $ged->individuals;
  my @families = $ged->families;
  my $me = $ged->get_individual("Paul Johnson");
  my $xref = $ged->next_xref("I");
  my $record = $ged->add_header;
                     add_submitter
                     add_individual
                     add_family
                     add_note
                     add_repository
                     add_source
                     add_trailer
  my $source = $ged->get_source("S1");

=head1 DESCRIPTION

This module provides for manipulation of GEDCOM files.  GEDCOM is a format for
storing genealogical information designed by The Church of Jesus Christ of
Latter-Day Saints (http://www.lds.org).  Information about GEDCOM used to be
available as a zip file at ftp://gedcom.org/pub/genealogy/gedcom/gedcom55.zip.
That may still be the case, but it seems to be password protected now.
However, the document in that archive seems to be available in a somewhat more
accessible format at
https://chronoplexsoftware.com/gedcomvalidator/gedcom/gedcom-5.5.pdf.

Requirements:

  Perl 5.005 or later
  ActivePerl5 Build Number 520 or later has been reported to work

Optional Modules:

  Date::Manip.pm       to work with dates
  Text::Soundex.pm     to use soundex
  Parse::RecDescent.pm to use lines2perl
  Roman.pm             to use the LifeLines function roman from lines2perl

The GEDCOM format is specified in a grammar file (gedcom-5.5.grammar).
Gedcom.pm parses the grammar which is then used to validate and allow
manipulation of the GEDCOM file.  I have only used Gedcom.pm with versions 5.5
and 5.5.1 of the GEDCOM grammar, which I had to modify slightly to correct a
few errors.  The advantage of this approach is that Gedcom.pm should be useful
if the GEDCOM grammar is ever updated.  It also made the software easier to
write, and probably more dependable too.  I suppose this is the virtue of
laziness shining through.

The vice of laziness is also shining brightly - I need to document how to use
this module in much greater detail.  This is happening - this release has more
documentation than the previous ones - but if you would like information feel
free to send me mail or better still, ask on the mailing list.

This module provides some functions which work over the entire GEDCOM file,
such as reformatting dates, renumbering entries and ordering the entries.  It
also allows access to individuals, and then to relations of individuals, for
example sons, siblings, spouse, parents and so forth.

The distribution includes a lines2perl program to convert LifeLines programs to
Perl.  The program works, but it has a few rough edges, and some missing
functionality.  I'll be working on it when it hits the top of my TODO list.

There is now an option for read only access to the GEDCOM file.  Actually, this
doesn't stop you changing or writing the file, but it does parse the GEDCOM
file lazily, meaning that only those portions of the GEDCOM file which are
needed will be read.  This can provide a substantial saving of time and memory
providing that not too much of the GEDCOM file is read.  If you are going to
read the whole GEDCOM file, this mode is less efficient unless you do some
manual housekeeping.

Should you find this software useful, or if you make changes to it, or if you
would like me to make changes to it, please send me mail.  I would like to have
some sort of an idea of the use this software is getting.  Apart from being of
interest to me, this will guide my decisions when I feel the need to make
changes to the interface.

There is a low volume mailing list available for discussing the use of Perl in
conjunction with genealogical work.  This is an appropriate forum for
discussing Gedcom.pm and if you use or are interested in this module I would
encourage you to join the list.  To subscribe send an empty message to
S<perl-gedcom-subscribe@perl.org>.

To store my genealogy I wrote a syntax file (gedcom.vim) and used vim
(http://www.vim.org) to enter the data, and Gedcom.pm to validate and
manipulate it.  I find this to be a nice solution.

=head1 GETTING STARTED

This space is reserved for something of a tutorial.  If you learn best by
looking at examples, take a look at the test directory, I<t>.  The most simple
test is I<birthdates.t>.

The first thing to do is to read in the GEDCOM file.  At its most simple, this
will involve a statement such as

  my $ged = Gedcom->new($gedcom_file);

It is now possible to access the records within the GEDCOM file.  Each
individual and family is a record.  Records can contain other records.  For
example, an individual is a record.  The birth information is a sub-record of
the individual, and the date of birth is a sub-record of the birth record.

Some records, such as the birth record, are simply containers for other
records.  Some records have a value, such as the date record, whose value is a
date.  This is all defined in the GEDCOM standard.

To access an individual use a statement such as

  my $i = $ged->get_individual("Paul Johnson");

To access information about the individual, use a function of the same name as
the GEDCOM tag, or its description.  Tags and descriptions are listed at the
head of Gedcom.pm.  For example

  for my $b ($i->birth) {
  }

will loop through all the birth records in the individual.  Usually there will
only be one such record, but there may be zero, one or more.  Calling the
function in scalar context will return only the first record.

  my $b = $i->birth;

But the second record may be returned with

  my $b = $i->birth(2);

If the record required has a value, for example

  my $n = $i->name;

then the value is returned, in this case the name of the individual.  If there
is no value, as is the case for the birth record, then the record itself is
returned.  If there is a value, but the record itself is required, then the
get_record() function can be used.

Information must be accessed through the GEDCOM structure so, for example, the
birthdate is accessed via the date record from the birth record within an
individual.

  my $d = $b->date;

Be aware that if you access a record in scalar context, but there is no such
record, then undef is returned.  In this case, $d would be undef if $b had no
date record.  This is another reason why looping through records is a nice
solution, all else being equal.

Access to values can also be gained through the get_value() function.  This is
a preferable solution where it is necessary to work down the GEDCOM structure.
For example

  my $bd = $i->get_value("birth date");
  my $bd = $i->get_value(qw(birth date));

will both return an individual's birth date or undef if there is none.  And

  my @bd = $i->get_value("birth date");

will return all the birth dates.  The second birth date, if there is one, is

  my $bd2 = $i->get_value(["birth", 2], "date");

Using the get_record() function in place of the get_value() function, in all
cases will return the record rather than the value.

All records are of a type derived from Gedcom::Item.  Individuals are of type
Gedcom::Individual.  Families are of type Gedcom::Family.  Events are of type
Gedcom::Event.  Other records are of type Gedcom::Record which is the base type
of Gedcom::Individual, Gedcom::Family and Gedcom::Event.

As individuals are of type Gedcom::Individual, the functions in
Gedcom::Individual.pm are available.  These allow access to relations and other
information specific to individuals, for example

  my @sons = $i->sons;

It is possible to get all the individuals in the GEDCOM file as

  my @individuals = $ged->individuals;

So putting everything together, here is a little program which will print out
the names and birthdates of everyone in a GEDCOM file specified on the command
line.

  #!/bin/perl -w

  use strict;
  use Gedcom;

  my $ged = Gedcom->new(shift);

  for my $i ($ged->individuals) {
      for my $bd ($i->get_value("birth date")) {
          print $i->name, " was born on $bd\n";
      }
  }

=head1 HASH MEMBERS

I have not gone the whole hog with data encapsulation and such within this
module.  Maybe I should have done.  Maybe I will.  For now though, the data is
accessible though hash members.  This is partly because having functions to do
this is a little slow, especially on my old DECstation, and partly because of
laziness again.  I'm not too sure whether this is good or bad laziness yet.
Time will tell no doubt.

As of version 1.05, you should be able to access all the data through
functions, and as of version 1.10 write access is available.  I have a faster
machine now.

Some of the more important hash members are:

=head2 $ged->{grammar}

This contains the GEDCOM grammar.

See Gedcom::Grammar.pm for more details.

=head2 $ged->{record}

This contains the top level gedcom record.  A record contains a number of
items.  Each of those items are themselves records.  This is the way in which
the hierarchies are modelled.

If you want to get at the data in the gedcom object, this is where you start.

See Gedcom::Record.pm for more details.

=head1 METHODS

=head2 new

  my $ged = Gedcom->new;

  my $ged = Gedcom->new($gedcom_file);

  my $ged = Gedcom->new(grammar_version => "5.5.1",
                        gedcom_file     => $gedcom_file,
                        read_only       => 1,
                        callback        => $cb);

  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);

Create a new gedcom object.

gedcom_file is the name of the GEDCOM file to parse.  If you do not supply a
gedcom_file parameter then you will get an empty Gedcom object, empty that is
apart from a few mandatory records.

You may optionally pass grammar_version as the version number of the GEDCOM
grammar you want to use.  There are two versions available, 5.5 and 5.5.1.  If
you do not specify a grammar version, you may specify a grammar file as
grammar_file.  Usually, you will do neither of these, and in this case the
grammar version will default to the latest full available version, currently
5.5.  5.5.1 is only a draft, but it is available if you specify it.

The read_only parameter indicates that the Gedcom data structure will be used
primarily for read_only operations.  In this mode the GEDCOM file is read
lazily, such that whenever possible the Gedcom records are not read until they
are needed.  This can save on both memory and CPU usage, provided that not too
much of the GEDCOM file is needed.  If the whole of the GEDCOM file needs to be
read, for example to validate it, or to write it out in a different format,
then this option should not be used.

When using the read_only option an index file is kept which can also speed up
operations.  It's usage should be transparent, but will require write access to
the directory containing the GEDCOM file.  If you access individuals only by
their xref (eg I20) then the index file will allow only the relevant parts of
the GEDCOM file to be read.

With or without the read_only option, the GEDCOM file is accessed in the same
fashion and the data structures can be changed.  In this respect, the name
read_only is not particularly accurate, but since changing the Gedcom data will
generally mean that the data will be written which means that the data will
first be read, the read_only option is generally useful when the data will not
be written and when not all the data will be read.  You may find it useful to
experiment with this option and check the amount of CPU time and memory that
your application uses.  You may also need to read this paragraph a few times to
understand it.  Sorry.

callback is an optional reference to a subroutine which will be called at
various times while the GEDCOM file (and the grammar file, if applicable) is
being read.  Its purpose is to provide feedback during potentially long
operations.  The subroutine is called with five arguments:

  my ($title, $txt1, $txt2, $current, $total) = @_;

  $title is a brief description of the current operation
  $txt1 and $txt2 provide more information on the current operation
  $current is the number of operations performed
  $total is the number of operations that need to be performed

If the subroutine returns false, the operation is aborted.

=head2 set_encoding

  $ged->set_encoding("utf-8");

Valid arguments are "ansel" and "utf-8".  Defaults to "ansel" but is set to
"utf-8" if the GEDCOM data was read from a file which was deemed to contain
UTF-8, either due to the presence of a BOM or as specified by a CHAR item.

Set the encoding for the GEDCOM file.  Calling this directly doesn't alter the
CHAR item, but does affect the way in which files are written.

=head2 write

  $ged->write($new_gedcom_file, $flush);

Write out the GEDCOM file.

Takes the name of the new GEDCOM file, and whether or not to indent the output
according to the level of the record.  $flush defaults to false, but the new
file name must be specified.

=head2 write_xml

  $ged->write_xml($new_xml_file);

Write the GEDCOM file as XML.

Takes the name of the new GEDCOM file.

Note that this function is experimental.  The XML output doesn't conform to any
standard; it's just me trying to turn the GEDCOM format into sensible XML.

=head2 collect_xrefs

  $ged->collect_xrefs($callback);

Collect all the xrefs into a data structure ($ged->{xrefs}) for easy location.
$callback is not used yet.

Called by new().

=head2 resolve_xref

  my $xref = $self->resolve_xref($value);

Return the record $value points to, or undef.

=head2 resolve_xrefs

  $ged->resolve_xrefs($callback);

Changes all xrefs to reference the record they are pointing to.  Like changing
a soft link to a hard link on a Unix filesystem.  $callback is not used yet.

=head2 unresolve_xrefs

  $ged->unresolve_xrefs($callback);

Changes all xrefs to name the record they contained.  Like changing a hard link
to a soft link on a Unix filesystem.  $callback is not used yet.

=head2 validate

  return unless $ged->validate($callback);

Validate the Gedcom object.  This performs a number of consistency checks, but
could do even more.  $callback is not properly used yet.

Any errors found are given out as warnings.  If this is unwanted, use
$SIG{__WARN__} to catch the warnings.

Returns true iff the Gedcom object is valid.

=head2 normalise_dates

  $ged->normalise_dates;
  $ged->normalise_dates("%A, %E %B %Y");

Change all recognised dates into a consistent format.  This routine uses
Date::Manip to do the work, so you can look at its documentation regarding
formats that are recognised and % sequences for the output.

Optionally takes a format to use for the output.  The default is currently
"%A, %E %B %Y", but I may change this, as it seems that some programs don't
like that format.

=head2 renumber

  $ged->renumber;
  my %xrefs = $ged->renumber(INDI => 34, FAM => 12, xrefs => [$xref1, $xref2]);

Renumber all the records.

Optional parameters are:

  tag name => last used number (defaults to 0)
  xrefs    => list of xrefs to renumber first

As a record is renumbered, it is assigned the next available number.  The
husband, wife, children, parents and siblings are then renumbered in that
order.  This helps to ensure that families are numerically close together.

The hash returned is the updated hash that was passed in.

=head2 sort_sub

  $ged->order($ged->sort_sub);

Default ordering subroutine.

The sort is by record type in the following order: HEAD, SUBM, INDI, FAM, NOTE,
TRLR, and then by xref within the type.

=head2 order

  $ged->order;
  $ged->order($order_sub);

Order all the records.  Optionally provide a sort subroutine.

This orders the entries within the Gedcom object, which will affect the order
in which they are written out.  The default sort function is Gedcom::sort_sub.
You will need to ensure that the HEAD record is first and that the TRLR record
is last.

=head2 individuals

  my @individuals = $ged->individuals;

Return a list of all the individuals.

=head2 families

  my @families = $ged->families;

Return a list of all the families.

=head2 get_individual

  my $me = $ged->get_individual("Paul Johnson");

Return a list of all individuals matching the specified name.

There are thirteen matches performed, in decreasing order of exactitude.  This
means that the more likely matches are at the head of the list.

In scalar context return the first match found.

The matches are:

   1 - Xref
   2 - Exact
   3 - On word boundaries
   4 - Anywhere
   5 - Exact, case insensitive
   6 - On word boundaries, case insensitive
   7 - Anywhere, case insensitive
   8 - Names in any order, on word boundaries
   9 - Names in any order, anywhere
  10 - Names in any order, on word boundaries, case insensitive
  11 - Names in any order, anywhere, case insensitive
  12 - Soundex code
  13 - Soundex of name

=head2 next_xref

  my $xref = $ged->next_xref("I");

Return the next available xref with the specified prefix.

=head2 add_record

       add_header
       add_submitter
       add_individual
       add_family
       add_note
       add_repository
       add_source
       add_trailer

Create and return a new record of the specified type.

Normally you will not want to pass any arguments to the function.  Those
functions which have an xref (ie not header or trailer) accept an optional
first argument { xref => $x } which will use $x as the xref rather than letting
the module automatically choose the xref.

add_note also accepts an optional second argument which is the text to be used
on the first line of the note.

=head2 get_record

       get_header
       get_submitter
       get_family
       get_note
       get_repository
       get_source
       get_trailer

Return all records of the specified type.  In scalar context just return the
first record.  If a parameter is passed in, just return records of that xref.

=head1 LICENCE

Copyright 1998-2019, Paul Johnson (paul@pjcj.net)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
http://www.pjcj.net

=cut
