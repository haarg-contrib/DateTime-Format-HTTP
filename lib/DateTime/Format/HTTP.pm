package DateTime::Format::HTTP;
use strict;
use warnings;
use vars qw( $VERSION );


$VERSION = '0.33';

use DateTime;
use HTTP::Date qw();

#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw(time2str str2time);
#@EXPORT_OK = qw(parse_date time2iso time2isoz);

use vars qw( @MoY %MoY);
@MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@MoY{@MoY} = (1..12);

sub format_datetime
{
    my $self = shift;
    my $dt = shift;
    $dt = DateTime->now unless defined $dt;
    $dt = $dt->clone->set_time_zone( 'UTC' );
    return $dt->strftime( "%a, %d %b %Y %H:%M:%S %Z" );
    #sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
    #        $mday, $MoY[$mon], $year+1900,
    #        $hour, $min, $sec);
}


sub parse_datetime
{
    my $self = shift;
    my $str = shift;
    die "No input string!" unless defined $str;
    #warn "In: [$str]\n";

    # fast exit for strictly conforming string
    if ($str =~ /^
	[SMTWF][a-z][a-z],
	\ (\d\d)
	\ ([JFMAJSOND][a-z][a-z])
	\ (\d\d\d\d)
	\ (\d\d):(\d\d):(\d\d)
	\ GMT$/x) {
	return DateTime->new(
	    day => $1,
	    month => $MoY{$2},
	    year => $3,
	    hour => $4,
	    minute => $5,
	    second => $6,
	    time_zone => 'GMT'
	);
    }

    my %d = $self->_parse_date($str);
    use Data::Dumper;
    die "Unable to parse date [$str]\n" unless keys %d;

    if (defined $d{time_zone})
    {
	$d{time_zone} = uc $d{time_zone} if $d{time_zone} eq 'z';
    }
    else
    {
	delete $d{time_zone};
    }
    for (qw( hour ))
    {
	delete $d{$_} if $d{$_} == 0;
    }

    my $frac = $d{second}; $frac -= ($d{second} = int($frac));
    my $nano = 100_000_000 * $frac; $d{nanosecond} = $nano;
    return DateTime->new( %d );
}


sub _parse_date
{
    my ($self, $str) = @_;
    my @fields = qw( year month day hour minute second time_zone );
    my %d;
    @d{@fields} = HTTP::Date::parse_date( $str );

    if (defined $d{time_zone}) {
	$d{time_zone} = "UTC" if $d{time_zone} =~ /^(GMT|UTC?|[-+]?0+)$/;
    }

    return %d;
}


sub format_iso
{
    my ($self, $dt) = @_;
    $dt = DateTime->now unless defined $dt;
    $dt->clone->set_time_zone( 'UTC' );
    sprintf("%04d-%02d-%02d %02d:%02d:%02d",
	$dt->year, $dt->month, $dt->day,
	$dt->hour, $dt->min, $dt->sec
    );
}


sub format_isoz
{
    my ($self, $dt) = @_;
    $dt = DateTime->now unless defined $dt;
    $dt->clone->set_time_zone( 'UTC' );
    sprintf("%04d-%02d-%02d %02d:%02d:%02dZ",
	$dt->year, $dt->month, $dt->day,
	$dt->hour, $dt->min, $dt->sec
    );
}

1;


__END__

=head1 NAME

DateTime::Format::HTTP - date conversion routines

=head1 SYNOPSIS

    use DateTime::Format::HTTP;

    my $class = 'DateTime::Format::HTTP';
    $string = $class->format_datetime($dt); # Format as GMT ASCII time
    $time = $class->parse_datetime($string); # convert ASCII date to machine time

=head1 DESCRIPTION

This module provides functions that deal the date formats used by the
HTTP protocol (and then some more).


=head1 METHODS

=head2 parse_datetime()

The parse_datetime() method converts a machine time (seconds since epoch)
to a string.  If the function is called without an argument, it will
use the current time.

The string returned is in the format preferred for the HTTP protocol.
This is a fixed length subset of the format defined by RFC 1123,
represented in Universal Time (GMT).  An example of a time stamp
in this format is:

   Sun, 06 Nov 1994 08:49:37 GMT

=over 4

=item str2time( $str [, $zone] )

The str2time() function converts a string to machine time.  It returns
C<undef> if the format of $str is unrecognized, or the time is outside
the representable range.  The time formats recognized are the same as
for parse_date().

The function also takes an optional second argument that specifies the
default time zone to use when converting the date.  This parameter is
ignored if the zone is found in the date string itself.  If this
parameter is missing, and the date string format does not contain any
zone specification, then the local time zone is assumed.

If the zone is not "C<GMT>" or numerical (like "C<-0800>" or
"C<+0100>"), then the C<Time::Zone> module must be installed in order
to get the date recognized.

=item parse_date( $str )

This function will try to parse a date string, and then return it as a
list of numerical values followed by a (possible undefined) time zone
specifier; ($year, $month, $day, $hour, $min, $sec, $tz).  The $year
returned will B<not> have the number 1900 subtracted from it and the
$month numbers start with 1.

In scalar context the numbers are interpolated in a string of the
"YYYY-MM-DD hh:mm:ss TZ"-format and returned.

If the date is unrecognized, then the empty list is returned.

The function is able to parse the following formats:

 "Wed, 09 Feb 1994 22:23:32 GMT"       -- HTTP format
 "Thu Feb  3 17:03:55 GMT 1994"        -- ctime(3) format
 "Thu Feb  3 00:00:00 1994",           -- ANSI C asctime() format
 "Tuesday, 08-Feb-94 14:15:29 GMT"     -- old rfc850 HTTP format
 "Tuesday, 08-Feb-1994 14:15:29 GMT"   -- broken rfc850 HTTP format

 "03/Feb/1994:17:03:55 -0700"   -- common logfile format
 "09 Feb 1994 22:23:32 GMT"     -- HTTP format (no weekday)
 "08-Feb-94 14:15:29 GMT"       -- rfc850 format (no weekday)
 "08-Feb-1994 14:15:29 GMT"     -- broken rfc850 format (no weekday)

 "1994-02-03 14:15:29 -0100"    -- ISO 8601 format
 "1994-02-03 14:15:29"          -- zone is optional
 "1994-02-03"                   -- only date
 "1994-02-03T14:15:29"          -- Use T as separator
 "19940203T141529Z"             -- ISO 8601 compact format
 "19940203"                     -- only date

 "08-Feb-94"         -- old rfc850 HTTP format    (no weekday, no time)
 "08-Feb-1994"       -- broken rfc850 HTTP format (no weekday, no time)
 "09 Feb 1994"       -- proposed new HTTP format  (no weekday, no time)
 "03/Feb/1994"       -- common logfile format     (no time, no offset)

 "Feb  3  1994"      -- Unix 'ls -l' format
 "Feb  3 17:03"      -- Unix 'ls -l' format

 "11-15-96  03:52PM" -- Windows 'dir' format

The parser ignores leading and trailing whitespace.  It also allow the
seconds to be missing and the month to be numerical in most formats.

If the year is missing, then we assume that the date is the first
matching date I<before> current month.  If the year is given with only
2 digits, then parse_date() will select the century that makes the
year closest to the current date.

=item time2iso( [$time] )

Same as time2str(), but returns a "YYYY-MM-DD hh:mm:ss"-formatted
string representing time in the local time zone.

=item time2isoz( [$time] )

Same as time2str(), but returns a "YYYY-MM-DD hh:mm:ssZ"-formatted
string representing Universal Time.


=back

=head1 SEE ALSO

L<perlfunc/time>, L<Time::Zone>

=head1 LICENSE AND COPYRIGHT

Copyright E<copy> Iain Truskett, 2003, except for the C<_parse_date>
function which is copyrigh 1995-1999 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the licenses can be found in the F<Artistic> and
F<COPYING> files included with this module.

=head1 AUTHOR

Iain Truskett <spoon@cpan.org>

=head1 SEE ALSO

C<datetime@perl.org> mailing list.

http://datetime.perl.org/

L<perl>, L<DateTime>, L<HTTP::Date>.

=cut
