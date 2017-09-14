package goto::file;
use strict;
use warnings;

our $VERSION = '0.003';

use Filter::Util::Call qw/filter_add/;

our %HANDLES;

my $ID = 1;
sub import {
    my $class = shift;
    my ($file) = @_;

    return unless $file;

    my @lines;
    push @lines => "#line " . __LINE__ . ' "' . __FILE__ . '"';
    push @lines => "package main;";
    push @lines => "\$@ = '';";

    my $id = $ID++;

    open(my $fh, '<', $file) or die "Cold not open file '$file': $!";

    $HANDLES{$id} = $fh;
    my $safe = $file;
    $safe =~ s/"/\\"/;
    push @lines => "#line " . (__LINE__ + 2) . ' "' . __FILE__ . '"';
    push @lines => (
        '{ local ($!, $?, $^E, $@); close(DATA); *DATA = $' . __PACKAGE__ . '::HANDLES{' . $id . '} }',
        qq{#line 1 "$safe"},
    );

    Filter::Util::Call::filter_add(
        bless { fh => $fh, lines => \@lines },
        $class
    );
}

sub filter {
    my $self = shift;

    my $lines = $self->{lines};
    my $fh    = $self->{fh};

    my $line;
    if (@$lines) {
        $line = shift @$lines;
    }
    elsif ($fh) {
        $line = <$fh>;
    }

    if (defined $line) {
        # Normalize to make sure each line ends with a newline.
        # Without this things choke on files with no terminal newline.
        chomp($line);
        $_ .= $line;
        $_ .= "\n";

        return 1;
    }

    return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

goto::file - Stop parsing the current file and move on to a different one.

=head1 DESCRIPTION

It is rare, but there are times where you want to swap out the currently
compiling file for a different one. This module does that. From the point you
C<use> the module perl will be parsing the new file instead of the original.

=head1 WHY?!

This was created specifically for L<Test2::Harness> which can preload modules
and fork to run each test. The problem was that using C<do> to execute the test
files post-fork was resuling in extra frames in the stack trace... in other
words there are a lot of tests that assume the test file is the bottom of the
stack. This happens all the time, specially if stack traces need to be
verified.

This module allows Test2::Harness to swap out the main script for the new file
without adding a stack frame.

=head1 SYNOPSIS

Plain and simple:

    #!/usr/bin/perl

    use goto::file 'some_file.pl';

    die "This will never be seen!";

    __DATA__

    This data will not be seen by <DATA>

More useful:

    #!/usr/bin/perl

    BEGIN {
        my $file = should_switch_files();

        if ($file) {
            print "about to switch to file '$file'\n";
            require goto::file;
            goto::file->import($file);
        }
    }

    print "Did not go to a file\n";

=head1 NOTES

=over 4

=item __DATA__ and <DATA>

This module does its very best to make sure the data you get from <DATA> comes
from the NEW file, and not the old. At the moment there are no known failure
cases, but there could be some.

=back

=head1 IMPLEMENTATION DETAILS

This is a source filter. The source filter simply disgards the lines from the
original file and instead feeds perl lines from the new file. There is also a
small source injection at the start that sets up C<< <DATA> >> and makes sure
line numbers and file name are all correct.

=head1 SOURCE

The source code repository for goto-file can be found at
F<http://github.com/exodist/goto-file/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
