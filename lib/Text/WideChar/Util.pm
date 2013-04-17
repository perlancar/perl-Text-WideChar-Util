package Text::WideChar::Util;

use 5.010001;
use locale;
use strict;
use utf8;
use warnings;

use List::Util qw(max);
use Text::CharWidth qw(mbswidth);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       mbpad
                       mbswidth_height
                       mbtrunc
                       mbwrap
                       wrap
               );

# VERSION

sub mbswidth_height {
    my $text = shift;
    my $num_lines = 0;
    my @lens;
    for my $e (split /(\r?\n)/, $text) {
        if ($e =~ /\n/) {
            $num_lines++;
            next;
        }
        $num_lines = 1 if $num_lines == 0;
        push @lens, mbswidth($e);
    }
    [max(@lens) // 0, $num_lines];
}

sub _wrap {
    my ($is_mb, $text, $width, $opts) = @_;
    $width //= 80;
    $opts  //= {};

    my $deffltab = $opts->{fltab};
    my $defsltab = $opts->{sltab};

    if (!defined($deffltab) || !defined($defsltab)) {
    }

    if (!defined($fltab)) {
        ($fltab) = $text =~ /^([ \t]*)\S/;
        $fltab //= "";
    }
    my $sltab = $opts->{sltab};
    if (!defined($sltab)) {
        ($sltab) = $text =~ /^[^\n]*\S[\n]*^([ \t+]*)\S/;
        $sltab //= "";
    }
    say "D:fltab=[$fltab], sltab=[$sltab]";

    my @res;

    # to wrap, first we

    my @ch = split /(\s+)/i, $text;

                my @p;

    my $col = 0;
    my $i = 0;
    while (my $p = shift(@p)) {
        $i++;
        my $num_nl = 0;
        my $is_pb; # paragraph break
        my $is_ws;
        my $w;
        #say "D:col=$col, p=$p";
        if ($p =~ /\A\s/s) {
            $is_ws++;
            $num_nl++ while $p =~ s/\r?\n//;
            if ($num_nl >= 2) {
                $is_pb++;
                $w = 0;
            } else {
                $p = " ";
                $w = 1;
            }
        } else {
            $w = mbswidth($p);
        }
        $col += $w;
        #say "D:col=$col, is_pb=${\($is_pb//0)}, is_ws=${\($is_ws//0)}, num_nl=$num_nl";

        if ($is_pb) {
            push @res, "\n" x $num_nl;
            $col = 0;
        } elsif ($col > $width+1) {
            # remove whitespace at the end of prev line
            if (@res && $res[-1] eq ' ') {
                pop @res;
            }

            push @res, "\n";
            if ($is_ws) {
                $col = 0;
            } else {
                push @res, $p;
                $col = $w;
            }
        } else {
            # remove space at the end of text
            if (@p || !$is_ws) {
                push @res, $p;
            } else {
                if ($num_nl == 1) {
                    push @res, "\n";
                }
            }
        }
    }
    join "", @res;
}

sub mbwrap {
    _wrap(1, @_);
}

sub wrap {
    _wrap(0, @_);
}

sub mbpad {
    my ($text, $width, $which, $padchar, $is_trunc) = @_;
    if ($which) {
        $which = substr($which, 0, 1);
    } else {
        $which = "r";
    }
    $padchar //= " ";

    my $w = mbswidth($text);
    if ($is_trunc && $w > $width) {
        my $res = mbtrunc($text, $width, 1);
        $text = $res->[0] . ($padchar x ($width-$res->[1]));
    } else {
        if ($which eq 'l') {
            $text = ($padchar x ($width-$w)) . $text;
        } elsif ($which eq 'c') {
            my $n = int(($width-$w)/2);
            $text = ($padchar x $n) . $text . ($padchar x ($width-$w-$n));
        } else {
            $text .= ($padchar x ($width-$w));
        }
    }
    $text;
}

sub mbtrunc {
    my ($text, $width, $return_width) = @_;

    my $w = mbswidth($text);
    die "Invalid argument, width must not be negative" unless $width >= 0;
    return $text if $w <= $width;

    # perform binary cutting
    my @res;
    my $wres = 0; # total width of text in @res
    my $l = int($w/2); $l = 1 if $l == 0;
    my $end;
    while (1) {
        my $left  = substr($text, 0, $l);
        my $right = substr($text, $l);
        my $wl = mbswidth($left);
        #say "D: left=$left, right=$right, wl=$wl";
        if ($wres + $wl > $width) {
            $text = $left;
        } else {
            push @res, $left;
            $wres += $wl;
            $text = $right;
        }
        $l = int(($l+1)/2);
        last if $l==1 && $end;
        $end++ if $l==1;
    }
    if ($return_width) {
        return [join("", @res), $wres];
    } else {
        return join("", @res);
    }
}

1;
# ABSTRACT: Routines for text containing wide characters

=encoding utf8

=head1 SYNOPSIS

 use Text::WideChar::Util qw(
     mbpad mbswidth_height mbtrunc mbwrap wrap);

 # get width as well as number of lines
 say mbswidth_height("red\n红色"); # => [4, 2]

 # wrap text to a certain column width
 say mbwrap("....", 40);

 # pad (left, right, center) text to specified column width, handle multilines
 say mbpad("foo", 10);                          # => "foo       "
 say mbpad("红色", 10, "left");                 # => "      红色"
 say mbpad("foo\nbarbaz\n", 10, "center", "."); # => "...foo....\n..barbaz..\n"

 # truncate text to a certain column width
 say mbtrunc("红色", 2 ); # => "红"
 say mbtrunc("红色", 3 ); # => "红"
 say mbtrunc("红red", 3); # => "红r"


=head1 DESCRIPTION

This module provides routines for dealing with text containing wide characters
(wide meaning occupying more than 1 column width in terminal).


=head1 FUNCTIONS

=head2 mbswidth_height($text) => [INT, INT]

Like L<Text::CharWidth>'s mbswidth(), but also gives height (number of lines).
For example, C<< mbswidth_height("foobar\nb\n") >> gives [6, 3].

=head2 mbwrap($text, $width) => STR

Wrap text to a specified column width.

C<$width> defaults to 80 if not specified.

Note: currently performance is rather abysmal (~ 1500/s on my Core i5-2400
3.1GHz desktop for a ~ 1KB of text), so call this routine sparingly ;-).

=head2 mbwrap($text, $width, \%opts) => STR

Wrap C<$text> to C<$width> columns. It uses mbswidth() instead of Perl's
length() which works on a per-character basis.

Options:

=over

=item * tab_width => INT (default: 8)

=item * fltab => STR

First line indent. If unspecified, will be deduced from the first line of text.

=item * sltab => STD

Subsequent line indent. If unspecified, will be deduced from the second line of
text, or if unavailable, will default to empty string (C<"">).

=back

=head2 wrap($text, $width, \%opts) => STR

Like mbwrap(), but uses character-based length() instead of column width-wise
mbswidth(). Provided as an alternative to the venerable L<Text::Wrap>'s wrap()
but with a different behaviour. This module's wrap() can reflow newline and its
behavior is more akin to Emacs (try reflowing a paragraph in Emacs using
C<M-q>).

=head2 mbpad($text, $width[, $which[, $padchar[, $truncate]]]) => STR

Return C<$text> padded with C<$padchar> to C<$width> columns. C<$which> is
either "r" or "right" for padding on the right (the default if not specified),
"l" or "left" for padding on the right, or "c" or "center" or "centre" for
left+right padding to center the text.

C<$padchar> is whitespace if not specified. It should be string having the width
of 1 column.

=head2 mbtrunc($text, $width) => STR

Truncate C<$text> to C<$width> columns. It uses mbswidth() instead of Perl's
length(), so it can handle wide characters.

Does *not* handle multiple lines.


=head1 FAQ

=head2 How do I truncate or pad to a certain character length (instead of column width)?

You can simply use Perl's substr() which works by character.


=head1 TODOS

=over

=back


=head1 SEE ALSO

L<Text::CharWidth> which provides mbswidth().

L<Text::ANSI::Util> which can also handle text containing wide characters as
well ANSI escape codes.

=cut
