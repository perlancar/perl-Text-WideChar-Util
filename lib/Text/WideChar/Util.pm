package Text::WideChar::Util;

use 5.010001;
use locale;
use strict;
use utf8;
use warnings;

use List::Util qw(max);
use Unicode::GCString;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       mbpad
                       pad
                       mbswidth
                       mbswidth_height
                       mbtrunc
                       trunc
                       mbwrap
                       wrap
               );

# VERSION

sub mbswidth {
    Unicode::GCString->new($_[0])->columns;
}

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

sub _get_indent_width {
    my ($is_mb, $indent, $tab_width) = @_;
    my $w = 0;
    for (split //, $indent) {
        if ($_ eq "\t") {
            # go to the next tab
            $w = $tab_width * (int($w/$tab_width) + 1);
        } else {
            $w += $is_mb ? mbswidth($_) : 1;
        }
    }
    $w;
}

sub _wrap {
    my ($is_mb, $text, $width, $opts) = @_;
    $width //= 80;
    $opts  //= {};

    # our algorithm: split into paragraphs, then process each paragraph. at the
    # start of paragraph, determine indents (either from %opts, or deduced from
    # text, like in Emacs) then push first-line indent. proceed to push words,
    # while adding subsequent-line indent at the start of each line.

    my $tw = $opts->{tab_width} // 8;
    die "Please specify a positive tab width" unless $tw > 0;
    my $optfli  = $opts->{flindent};
    my $optfliw = _get_indent_width($is_mb, $optfli, $tw) if defined $optfli;
    my $optsli  = $opts->{slindent};
    my $optsliw = _get_indent_width($is_mb, $optsli, $tw) if defined $optsli;
    my @res;

    my @para = split /(\n(?:[ \t]*\n)+)/, $text;

    my ($maxww, $minww);

  PARA:
    while (my ($ptext, $pbreak) = splice @para, 0, 2) {
        my $x = 0;
        my $y = 0;
        my $line_has_word = 0;

        # determine indents
        my ($fli, $sli, $fliw, $sliw);
        if (defined $optfli) {
            $fli  = $optfli;
            $fliw = $optfliw;
        } else {
            # XXX emacs can also treat ' #' as indent, e.g. when wrapping
            # multi-line perl comment.
            ($fli) = $ptext =~ /\A([ \t]*)\S/;
            if (defined $fli) {
                $fliw = _get_indent_width($is_mb, $fli, $tw);
            } else {
                $fli  = "";
                $fliw = 0;
            }
        }
        if (defined $optsli) {
            $sli  = $optsli;
            $sliw = $optsliw;
        } else {
            ($sli) = $ptext =~ /\A[^\n]*\S[\n]([ \t+]*)\S/;
            if (defined $sli) {
                $sliw = _get_indent_width($is_mb, $sli, $tw);
            } else {
                $sli  = "";
                $sliw = 0;
            }
        }
        die "Subsequent indent must be less than width" if $sliw >= $width;

        push @res, $fli;
        $x += $fliw;

        # process each word
        for my $word0 ($ptext =~ /(\S+)/g) {
            my @words;
            my @wordsw;
            while (1) {
                my $wordw = $is_mb ? mbswidth($word0) : length($word0);

                if ($wordw <= $width-$sliw) {
                    push @words , $word0;
                    push @wordsw, $wordw;
                    last;
                }
                # truncate long word
                if ($is_mb) {
                    my $res = mbtrunc($text, $width-$sliw, 1);
                    push @words , $res->[0];
                    push @wordsw, $res->[1];
                    $word0 = substr($word0, length($res->[0]));
                } else {
                    my $w2 = substr($word0, 0, $width-$sliw);
                    push @words , $w2;
                    push @wordsw, $width-$sliw;
                    $word0 = substr($word0, $width-$sliw);
                }
            }

            for my $word (@words) {
                my $wordw = shift @wordsw;
                #say "D:x=$x word=$word wordw=$wordw line_has_word=$line_has_word width=$width";

                $maxww = $wordw if !defined($maxww) || $maxww < $wordw;
                $minww = $wordw if !defined($minww) || $minww > $wordw;

                if ($x + ($line_has_word ? 1:0) + $wordw <= $width) {
                    if ($line_has_word) {
                        push @res, " ";
                        $x++;
                    }
                    push @res, $word;
                    $x += $wordw;
                } else {
                    push @res, "\n", $sli, $word;
                    $x = $sliw + $wordw;
                    $y++;
                }
                $line_has_word++;
            }
        }

        if (defined $pbreak) {
            push @res, $pbreak;
        } else {
            push @res, "\n" if $ptext =~ /\n[ \t]*\z/;
        }
    }

    if ($opts->{return_stats}) {
        return [join("", @res), {
            max_word_width => $maxww,
            min_word_width => $minww,
        }];
    } else {
        return join("", @res);
    }
}

sub mbwrap {
    _wrap(1, @_);
}

sub wrap {
    _wrap(0, @_);
}

sub _pad {
    my ($is_mb, $text, $width, $which, $padchar, $is_trunc) = @_;
    if ($which) {
        $which = substr($which, 0, 1);
    } else {
        $which = "r";
    }
    $padchar //= " ";

    my $w = $is_mb ? mbswidth($text) : length($text);
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

sub mbpad {
    _pad(1, @_);
}

sub pad {
    _pad(0, @_);
}

sub _trunc {
    my ($is_mb, $text, $width, $return_width) = @_;

    # return_width (undocumented): if set to 1, will return [truncated_text,
    # visual width, length(chars) up to truncation point]

    my $w = $is_mb ? mbswidth($text) : length($text);
    die "Invalid argument, width must not be negative" unless $width >= 0;
    if ($w <= $width) {
        return $return_width ? [$text, $w, length($text)] : $text;
    }

    my $c = 0;

    # perform binary cutting
    my @res;
    my $wres = 0; # total width of text in @res
    my $l = int($w/2); $l = 1 if $l == 0;
    my $end = 0;
    while (1) {
        my $left  = substr($text, 0, $l);
        my $right = $l > length($text) ? "" : substr($text, $l);
        my $wl = $is_mb ? mbswidth($left) : length($left);
        #say "D:left=$left, right=$right, wl=$wl";
        if ($wres + $wl > $width) {
            $text = $left;
        } else {
            push @res, $left;
            $wres += $wl;
            $c += length($left);
            $text = $right;
        }
        $l = int(($l+1)/2);
        #say "D:l=$l";
        last if $l==1 && $end>1;
        $end++ if $l==1;
    }
    if ($return_width) {
        return [join("", @res), $wres, $c];
    } else {
        return join("", @res);
    }
}

sub mbtrunc {
    _trunc(1, @_);
}

sub trunc {
    _trunc(0, @_);
}

1;
# ABSTRACT: Routines for text containing wide characters

=encoding utf8

=head1 SYNOPSIS

 use Text::WideChar::Util qw(
     mbpad pad mbswidth mbswidth_height mbtrunc trunc mbwrap wrap);

 # get width as well as number of lines
 say mbswidth_height("red\n红色"); # => [4, 2]

 # wrap text to a certain column width
 say mbwrap("....", 40);

 # pad (left, right, center) text to specified column width, handle multilines
 say mbpad("foo", 10);                          # => "foo       "
 say mbpad("红色", 10, "left");                 # => "      红色"
 say mbpad("foo\nbarbaz\n", 10, "center", "."); # => "...foo....\n..barbaz..\n"

 # truncate text to a certain column width
 say mbtrunc("红色",  2); # => "红"
 say mbtrunc("红色",  3); # => "红"
 say mbtrunc("红red", 3); # => "红r"


=head1 DESCRIPTION

This module provides routines for dealing with text containing wide characters
(wide meaning occupying more than 1 column width in terminal).


=head1 FUNCTIONS

=head1 mbswidth($text) => INT

Like L<Text::CharWidth>'s mbswidth(), except implemented using L<<
Unicode::GCString->new($text)->columns >>.

=head2 mbswidth_height($text) => [INT, INT]

Like mbswidth(), but also gives height (number of lines). For example, C<<
mbswidth_height("foobar\nb\n") >> gives [6, 3].

=head2 mbwrap($text, $width, \%opts) => STR

Wrap C<$text> to C<$width> columns. It uses mbswidth() instead of Perl's
length() which works on a per-character basis.

Options:

=over

=item * tab_width => INT (default: 8)

Set tab width.

Note that tab will only have effect on the indent. Tab between text will be
replaced with a single space.

=item * flindent => STR

First line indent. If unspecified, will be deduced from the first line of text.

=item * slindent => STD

Subsequent line indent. If unspecified, will be deduced from the second line of
text, or if unavailable, will default to empty string (C<"">).

=item * return_stats => BOOL (default: 0)

If set to true, then instead of returning the wrapped string, function will
return C<< [$wrapped, $stats] >> where C<$stats> is a hash containing some
information like C<max_word_width>, C<min_word_width>.

=back

Performance: ~650/s on my Core i5 1.7GHz laptop for a 1KB of text.

=head2 wrap($text, $width, \%opts) => STR

Like mbwrap(), but uses character-based length() instead of column width-wise
mbswidth(). Provided as an alternative to the venerable L<Text::Wrap>'s wrap()
but with a different behaviour. This module's wrap() can reflow newline and its
behavior is more akin to Emacs (try reflowing a paragraph in Emacs using
C<M-q>).

Performance: ~2000/s on my Core i5 1.7GHz laptop for a ~1KB of text.
Text::Wrap::wrap() on the other hand is ~2500/s.

=head2 mbpad($text, $width[, $which[, $padchar[, $truncate]]]) => STR

Return C<$text> padded with C<$padchar> to C<$width> columns. C<$which> is
either "r" or "right" for padding on the right (the default if not specified),
"l" or "left" for padding on the right, or "c" or "center" or "centre" for
left+right padding to center the text.

C<$padchar> is whitespace if not specified. It should be string having the width
of 1 column.

=head2 pad($text, $width[, $which[, $padchar[, $truncate]]]) => STR

The non-wide version of mbpad(), just like in mbwrap() vs wrap().

=head2 mbtrunc($text, $width) => STR

Truncate C<$text> to C<$width> columns. It uses mbswidth() instead of Perl's
length(), so it can handle wide characters.

Does *not* handle multiple lines.

=head2 trunc($text, $width) => STR

The non-wide version of mbtrunc(), just like in mbwrap() vs wrap(). This is
actually not much more than Perl's C<< substr($text, 0, $width) >>.


=head1 INTERNAL NOTES

Should we wrap at hyphens? Probably not. Both Emacs as well as Text::Wrap do
not.


=head1 TODOS

=over

=back


=head1 SEE ALSO

L<Unicode::GCString> which is consulted for visual width of characters.
L<Text::CharWidth> is about 2.5x faster but it gives weird results (-1 for
characters like "\n" and "\t") and my Strawberry Perl installation fails to
build it.

L<Text::ANSI::Util> which can also handle text containing wide characters as
well ANSI escape codes.

=cut
