use strict;
use warnings;

use Test::More tests => 126;

use Gedcom;

{
    my $gedcom_file = "gedcompm.ged";

    my $ged = Gedcom->new;
    isa_ok( $ged, 'Gedcom' );

    ok my $i1 = $ged->add_individual("O5");
    ok $i1->add("name", "Fred /Bloggs/");
    ok $i1->add("birth date", "20 Dec 1775");
    ok $i1->add("birth", ["date", 2], "21 Dec 1775");
    ok $i1->add(["birth", 2], "date", "22 Dec 1775");
    ok $i1->add("sex", "M");

    ok my $ix = $ged->add_individual("O");
    ok $ix->add("name", "John /Smith/");
    ok $ix->add("christening date", "15 July 1954");
    ok $ix->add("christening date", "25 July 1954");
    ok $ix->add("sex", "F");

    ok my $i2 = $ged->add_individual;
    ok $i2->add("name", "Betty /Bloggs/");
    ok $i2->add("christening date", "11 May 1777");
    ok $i2->add("sex", "F");

    ok my $i3 = $ged->add_individual;
    ok $i3->add("name", "Jane /Bloggs/");

    ok my $i4 = $ged->add_individual;
    ok $i4->add("name", "Joe /Bloggs/");
    ok $i4->add("birth date", "2 Feb 1802");
    ok $i4->set("birth date", "3 Feb 1802");
    ok $i4->add("sex", "M");

    ok my $f1 = $ged->add_family;
    ok $f1->add_husband($i1);
    ok $f1->add_wife($i2);
    ok $f1->add_child($i3);
    ok $f1->add_child($i4);

    ok my $n1 = $ged->add_note("First line");
    ok $n1->add("cont", "This is a note.");
    ok $n1->add("cont", "Please take notice.");
    ok $n1->add("conc", "There's more.  O");
    ok $n1->add("conc", "k, that's it.");

    ok my $n2 = $ged->add_note({ xref => "N100" }, "Note 2");

    ok $i4->add("note", "This is a note on one line");
    ok $i4->add("note", $n2);

    ok $i2->delete;

    ok my $i5 = $ged->add_individual;
    ok $i5->add("name", "Susan /Bloggs/");
    ok $i5->add("christening date", "11 May 1778");
    ok $i5->add("sex", "F");

    my $obj1 = $i5->add("OBJE", 12);
    my $obj2 = $i5->add("OBJE");
    $obj2->add("FORM", "qqq");
    $obj2->add("FILE", "rrr");

    ok $f1->add_wife($i5);

    ok $f1->delete;

    ok $ged->renumber;
    ok $ged->order;

    $ged->write($gedcom_file);

    {
        my $w = 0;
        local $SIG{ __WARN__ } = sub { $w++ };

        ok !$ged->validate, 'Gedcom file is not valid';
        is $w, 2, '2 warnings thrown';
    }

    ok -e $gedcom_file, "$gedcom_file exists";

    # check the gedcom file is correct
    ok open F1, $gedcom_file;
    my @ged_data = <DATA>;
    for (@ged_data)
    {
        my $f = <F1>;
        is $f, $_, "line $. matches" unless m{Ignore};
    }

    ok eof, 'No more lines to compare';
    ok close F1;
    ok unlink $gedcom_file;
}

__DATA__
0 HEAD
1   SOUR Gedcom.pm
2     NAME Gedcom.pm
2     VERS Ignore
2     CORP Paul Johnson
3       ADDR http://www.pjcj.net
2     DATA
3       COPR Copyright 1998-2019, Paul Johnson (paul@pjcj.net)
1   NOTE
2     CONT This output was generated by Gedcom.pm.
2     CONT Gedcom.pm is Copyright 1998-2019, Paul Johnson (paul@pjcj.net)
2     CONT Version 1.21 - 14th November 2019
2     CONT
2     CONT Gedcom.pm is free.  It is licensed under the same terms as Perl itself.
2     CONT
2     CONT The latest version of Gedcom.pm should be available from my homepage:
2     CONT http://www.pjcj.net
1   GEDC
2     VERS 5.5
2     FORM LINEAGE-LINKED
1   DATE Ignore
1   CHAR ANSEL
1   SUBM @SUBM1@

0 @SUBM1@ SUBM
1   NAME Ignore

0 @I1@ INDI
1   NAME Fred /Bloggs/
1   BIRT
2     DATE 20 Dec 1775
2     DATE 21 Dec 1775
1   BIRT
2     DATE 22 Dec 1775
1   SEX M
1   FAMS F1

0 @I2@ INDI
1   NAME John /Smith/
1   CHR
2     DATE 15 July 1954
2     DATE 25 July 1954
1   SEX F

0 @I3@ INDI
1   NAME Jane /Bloggs/
1   FAMC F1

0 @I4@ INDI
1   NAME Joe /Bloggs/
1   BIRT
2     DATE 3 Feb 1802
1   SEX M
1   FAMC F1
1   NOTE This is a note on one line
1   NOTE @N2@

0 @I5@ INDI
1   NAME Susan /Bloggs/
1   CHR
2     DATE 11 May 1778
1   SEX F
1   OBJE 12
1   OBJE
2     FORM qqq
2     FILE rrr
1   FAMS F1

0 @N1@ NOTE First line
1   CONT This is a note.
1   CONT Please take notice.
1   CONC There's more.  O
1   CONC k, that's it.

0 @N2@ NOTE Note 2

0 TRLR
