#!perl -T

use 5.010001;
use strict;
use warnings;
use utf8;
use constant NL => "\n";

use POSIX;
use Test::More 0.98;
use Text::WideChar::Util qw(wrap);

# XXX test flindent opt is wider than width
# XXX test flindent from text is wider than width

{
    my $u = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr Goh,
I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    my $w = <<_;
I dont wan't to go home. Where do you
want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me
company.
_
    is(wrap($u, 40), $w, "single paragraph");
}

{
    my $u = <<_;
I dont wan't to go home.
Where do you want to go?
I'll keep you company.
Mr Goh, I'm fine. You
don't have to keep me
company.
_
#--------1---------2---------3---------4
    my $w = <<_;
I dont wan't to go home. Where do you
want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me
company.
_
    is(wrap($u, 40), $w, "reflow");
}

{
    my $u = "I dont wan't to go home.
Where do you want to go?
I'll keep you company.
Mr Goh, I'm fine. You
don't have to keep me
company.";
#--------1---------2---------3---------4
    my $w = "I dont wan't to go home. Where do you
want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me
company.";
    is(wrap($u, 40), $w, "trailing newline state is preserved (no newline)");
}

subtest "paragraph break characters are maintained" => sub {
    is(wrap("a\n\nb", 40), "a\n\nb", "\\n\\n");
    is(wrap("a\n\n\nb", 40), "a\n\n\nb", "\\n\\n\\n");
    is(wrap("a\n \nb", 40), "a\n \nb", "\\n \\n");
    is(wrap("a\n\n\nb\n\n", 40), "a\n\n\nb\n\n", "\\n\\n at the end");
};

subtest "flindent & slindent deduced from text" => sub {
    my $u = <<_;
  I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    my $w = <<_;
  I dont wan't to go home. Where do you
want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me
company.
_
    is(wrap($u, 40), $w, "flindent");

    $u = <<_;
  I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
    Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    $w = <<_;
  I dont wan't to go home. Where do you
    want to go? I'll keep you company.
    Mr Goh, I'm fine. You don't have to
    keep me company.
_
    is(wrap($u, 40), $w, "flindent + slindent");

#--------1---------2---------3---------4
    $u = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
    Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    $w = <<_;
I dont wan't to go home. Where do you
    want to go? I'll keep you company.
    Mr Goh, I'm fine. You don't have to
    keep me company.
_
    is(wrap($u, 40), $w, "slindent");

    $u = <<_;
  I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
    Goh, I'm fine. You don't have to keep me company.

    I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    $w = <<_;
  I dont wan't to go home. Where do you
    want to go? I'll keep you company.
    Mr Goh, I'm fine. You don't have to
    keep me company.

    I dont wan't to go home. Where do
you want to go? I'll keep you company.
Mr Goh, I'm fine. You don't have to keep
me company.
_
    is(wrap($u, 40), $w, "flindent + slindent is reset every para");
};

subtest "flindent & slindent option" => sub {
    my $u = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    my $w = <<_;
  I dont wan't to go home. Where do you
 want to go? I'll keep you company. Mr
 Goh, I'm fine. You don't have to keep
 me company.
_
    is(wrap($u, 40, {flindent=>'  ', slindent=>' '}), $w,
       "flindent + slindent");

    $u = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
Goh, I'm fine. You don't have to keep me company.

  I dont wan't to go home. Where do you want to go? I'll keep you company. Mr
    Goh, I'm fine. You don't have to keep me company.
_
#--------1---------2---------3---------4
    $w = <<_;
  I dont wan't to go home. Where do you
 want to go? I'll keep you company. Mr
 Goh, I'm fine. You don't have to keep
 me company.

  I dont wan't to go home. Where do you
 want to go? I'll keep you company. Mr
 Goh, I'm fine. You don't have to keep
 me company.
_
    is(wrap($u, 40, {flindent=>'  ', slindent=>' '}), $w,
       "flindent + slindent is the same at every para");
};

subtest "tab_width option (flindent)" => sub {
# --------1---------2
    my $u0 = "I don't want to go home.\n";
    is(wrap($u0, 20, {flindent=>"\t"}), "\tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>" \t"}), " \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"  \t"}), "  \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"   \t"}), "   \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"    \t"}), "    \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"     \t"}), "     \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"      \t"}), "      \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"       \t"}), "       \tI don't want\nto go home.\n");
    is(wrap($u0, 20, {flindent=>"        \t"}), "        \tI\ndon't want to go\nhome.\n");
};

# TODO: tab_width option (slindent)

subtest "chop long word" => sub {
    is(wrap("1234567890",  5), "12345\n67890");
    is(wrap("12345678901", 5), "12345\n67890\n1");
    is(wrap("  12345678901", 5), "  \n12345\n67890\n1");
    is(wrap("  12345678901", 5, {slindent=>" "}), "  \n 1234\n 5678\n 901");
};

subtest "opt return_stats" => sub {
    is_deeply(wrap("12345 123", 10, {return_stats=>1}),
              ["12345 123", {max_word_width=>5, min_word_width=>3}],
              "opt return_stats");
};

DONE_TESTING:
done_testing();
