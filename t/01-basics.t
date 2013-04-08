#!perl -T

use 5.010001;
use strict;
use warnings;
use utf8;
use constant NL => "\n";

use POSIX;
use Test::More 0.98;
use Text::WideChar::Util qw(mbpad mbswidth_height mbwrap mbtrunc);

subtest "mbswidth_height" => sub {
    is_deeply(mbswidth_height(""), [0, 0]);
    is_deeply(mbswidth_height("我不想回家"), [10, 1]);
    is_deeply(mbswidth_height("我不想\n回家"), [6, 2]);
    is_deeply(mbswidth_height("我不\n想回家\n"), [6, 3]);
};

# single paragraph
my $txt1 = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr Goh,
I'm fine. You don't have to keep me company.
_
#qq--------10--------20--------30--------40--------50
my $txt1w =
qq|I dont wan't to go home. Where do you|.NL.
qq|want to go? I'll keep you company. Mr|.NL.
qq|Goh, I'm fine. You don't have to keep me|.NL.
qq|company.|.NL;

# multiple paragraph
my $txt1b = <<_;
I dont wan't to go home. Where do you want to go? I'll keep you company. Mr Goh,
I'm fine. You don't have to keep me company.

I dont wan't to go home. Where do you want to go? I'll keep you company. Mr Goh,
I'm fine. You don't have to keep me company.
_
#qq--------10--------20--------30--------40--------50
my $txt1bw =
qq|I dont wan't to go home. Where do you|.NL.
qq|want to go? I'll keep you company. Mr|.NL.
qq|Goh, I'm fine. You don't have to keep me|.NL.
qq|company.|.NL.NL.
qq|I dont wan't to go home. Where do you|.NL.
qq|want to go? I'll keep you company. Mr|.NL.
qq|Goh, I'm fine. You don't have to keep me|.NL.
qq|company.|.NL;

# no terminating newline
my $txt1c = "\x1b[31;47mI\x1b[0m dont wan't to go home. Where do you want to go? I'll keep you company. Mr Goh,
I'm fine. You don't have to keep...";
#qq--------10--------20--------30--------40--------50
my $txt1cw =
qq|\x1b[31;47mI\x1b[0m dont wan't to go home. Where do you|.NL.
qq|want to go? I'll keep you company. Mr|.NL.
qq|Goh, I'm fine. You don't have to keep...|;

# containing wide chars
my $txt2 = <<_;
I dont wan't to go home. 我不想回家. Where do you want to go? I'll keep you
company. 那你想去哪里？我陪你. Mr Goh, I'm fine. 吴先生. 我没事. You don't have
to keep me company. 你不用陪我.
_
#qq--------10--------20--------30--------40--------50
my $txt2w =
qq|I dont wan't to go home. 我不想回家.|.NL.
qq|Where do you want to go? I'll keep you|.NL.
qq|company. 那你想去哪里？我陪你. Mr Goh,|.NL.
qq|I'm fine. 吴先生. 我没事. You don't have|.NL.
qq|to keep me company. 你不用陪我.|.NL;

subtest "mbwrap" => sub {
    is(mbwrap($txt1 , 40), $txt1w );
    is(mbwrap($txt1b, 40), $txt1bw);
    is(mbwrap($txt2 , 40), $txt2w );
};

subtest "mbtrunc" => sub {
    my $t = "\x1b[31m1\x1b[32m2\x1b[33m3\x1b[0m4";
    is(ta_trunc($t, 5), $t);
    is(ta_trunc($t, 4), $t);
    is(ta_trunc($t, 3), "\x1b[31m1\x1b[32m2\x1b[33m3\x1b[0m");
    is(ta_trunc($t, 2), "\x1b[31m1\x1b[32m2\x1b[33m\x1b[0m");
    is(ta_trunc($t, 1), "\x1b[31m1\x1b[32m\x1b[33m\x1b[0m");
    is(ta_trunc($t, 0), "\x1b[31m\x1b[32m\x1b[33m\x1b[0m");
    is(ta_mbtrunc($t, 9), $t);
    is(ta_mbtrunc($t, 8), $t);
    is(ta_mbtrunc($t, 7), "\x1b[31m不\x1b[32m用\x1b[33m陪\x1b[0m我"); # well, ...
    is(ta_mbtrunc($t, 6), "\x1b[31m不\x1b[32m用\x1b[33m陪\x1b[0m");
    is(ta_mbtrunc($t, 5), "\x1b[31m不\x1b[32m用\x1b[33m陪\x1b[0m"); # well, ...
    is(ta_mbtrunc($t, 4), "\x1b[31m不\x1b[32m用\x1b[33m\x1b[0m");
    is(ta_mbtrunc($t, 3), "\x1b[31m不\x1b[32m用\x1b[33m\x1b[0m"); # well, ...
    is(ta_mbtrunc($t, 2), "\x1b[31m不\x1b[32m\x1b[33m\x1b[0m");
    is(ta_mbtrunc($t, 1), "\x1b[31m不\x1b[32m\x1b[33m\x1b[0m"); # well, ...
    is(ta_mbtrunc($t, 0), "\x1b[31m\x1b[32m\x1b[33m\x1b[0m");
};

DONE_TESTING:
done_testing();
