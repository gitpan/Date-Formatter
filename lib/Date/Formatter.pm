
package Date::Formatter;

use strict;
use warnings;

our $VERSION = '0.01';

## overload operators
use overload (
	'""'  => "toString",	
	'=='  => "equal",
	'!='  => "notEqual",
	'<=>' => "compare",
	'+'   => "add",
	'-'   => "subtract"
	);

## class constants
# date name constants
use constant DAYS => [ qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday) ];
use constant MONTHS => [ qw(January February March April May June July August September October November December) ]; 

### constructor

sub new {
	my ($_class) = @_;
	my $class = ref($_class) || $_class;
	my $date = {};
	bless($date, $class);
	$date->_init();
	return $date;
}

# alias "now" for "new" as an 
# alternate constructor semantic
*now = \&new;

sub _init {
	my ($self) = @_;
	$self->{hourType} = 12;
	$self->{abbreviateMonths} = 0;
	$self->{abbreviateDays} = 0;
	$self->{formatter} = undef;
	$self->{internal} = [];
	$self->{elements} = undef;
	$self->{am_or_pm} = undef;
	$self->{gmt_offset_hours} = undef;
	$self->{gmt_offset_minutes}	= undef;
	$self->_setTime(time());
}

## alternate constructor 
# for creating intervals of time.
# --------------------------------------
# this is best used with the overloaded
# versions of the '+' and '-' operator
# to increment and decrement another
# date object.
#
# Accepts the following named arguments:
#  - > years (365 days)
#  - > leap years (366 days)
#  - > months (assumes 30 days)
#  - > weeks
#  - > days
#  - > hours
#  - > minutes
#  - > seconds
#
# NOTE:
# This can also be used to set a time
# sometime past the epoch, but that is
# not terribly useful. Except maybe to
# pass in nothing and get the date of the
# epoch on your current system.
sub createTimeInterval {
	my ($class, %_date) = @_;
	my $time = 0;
	if (exists($_date{years}) && $_date{years}){
		$time += $_date{years} * 365 * 24 * 60 * 60;
	}
	if (exists($_date{leapyears}) && $_date{leapyears}){
		$time += $_date{leapyears} * 366 * 24 * 60 * 60;
	}
	if (exists($_date{months}) && $_date{months}){
		$time += $_date{months} * 30 * 24 * 60 * 60;
	}
	if (exists($_date{weeks}) && $_date{weeks}){
		$time += $_date{weeks} * 7 * 24 * 60 * 60;
	}
	if (exists($_date{days}) && $_date{days}){
		$time += $_date{days} * 24 * 60 * 60;
	}
	if (exists($_date{hours}) && $_date{hours}){
		$time += $_date{hours} * 60 * 60;
	}
	if (exists($_date{minutes}) && $_date{minutes}){
		$time += $_date{minutes} * 60;
	}
	if (exists($_date{seconds}) && $_date{seconds}){
		$time += $_date{seconds};
	}
	# if the are asking for nothing then
	# give them 1 second past the epoch
	$time ||= 1;
	return _setTime($class->new(), $time);
}

# occasionally you will want to refresh 
# the time to be the current time. This 
# would allow a Date object to be used
# over a long period of time
sub refresh {
	my ($self) = @_;
	$self->_init();
	return $self;
}

# creates a formatter subroutine to be used when 
# the date object is printed:
# 	print $date;
# (see below for more documentation)
{

	my %_parser_table = (
		"MM" 	=> \&getNumericMonth,
		"M" 	=> \&getMonth,
		"DD" 	=> \&getDayOfMonth,
		"D" 	=> \&getDayOfWeek,
		"YY" 	=> \&getYear,
		"YYYY" 	=> \&getFullYear,
		"hh" 	=> \&getHours,
		"mm" 	=> \&getMinutes,
		"ss" 	=> \&getSeconds,
		"T" 	=> \&isAMorPM,
		"O"		=> \&getGMTOffset
	);
	
	sub createDateFormatter {
		my ($self, $format, $pattern) = @_;
		my @date_format;
		$pattern ||= qr/\(|\)/;
		my @tokens = split $pattern => $format;
		while (@tokens) {
			my $token = shift(@tokens);
			if (exists $_parser_table{$token}) {
				push @date_format, $_parser_table{$token};
			}
			else {
				push @date_format, sub{ return "$token" };
			}
		}
		$self->{formatter} = sub {
			my ($self) = @_;
			return join "" => map {
				$_->($self);
			} @date_format;
		};
		return $self;
	}	
	
}

sub getDateFormatter {
	my ($self) = @_;
	return $self->{formatter};
}

sub setDateFormatter {
	my ($self, $formatter) = @_;
	(defined($formatter) && ref($formatter) eq "CODE") || die "Insufficient Arguments : bad formatter";
	$self->{formatter} = $formatter;
}

## private
	
# special private subroutine
# to set the internal time of 
# a date object after it is 
# created. This is used by:
# - createTimeInterval
# - add
# - subtract
sub _setTime { 
	my ($date, $new_time) = @_;
	$date->{internal} = $new_time;
	$date->{elements} = [ localtime($new_time) ];
	# must undefine this so that
	# it gets re-generated
	$date->{am_or_pm} = undef;
	my ($gmt_minutes, $gmt_hours) = (gmtime($new_time))[1, 2];
	$date->{gmt_offset_hours} = ($date->{elements}->[2] - $gmt_hours);
	$date->{gmt_offset_minutes} = ($date->{elements}->[1] - $gmt_minutes);	
	return $date;
}

## configuration

# use 12 or 24 hour clock
sub use24HourClock {
	my ($self) = @_;
	$self->{hourType} = 24;	
}

sub use12HourClock {
	my ($self) = @_;
	$self->{hourType} = 12;	
}

# use short or long names for months and days
sub useLongNames {
	my ($self) = @_;
	$self->{abbreviateMonths} = 0;
	$self->{abbreviateDays} = 0;
}

sub useLongMonthNames {
	my ($self) = @_;
	$self->{abbreviateMonths} = 0;
}

sub useLongDayNames {
	my ($self) = @_;
	$self->{abbreviateDays} = 0;
}

# short names are the first 3 letters
sub useShortNames {
	my ($self) = @_;
	$self->{abbreviateMonths} = 1;
	$self->{abbreviateDays} = 1;
}

sub useShortMonthNames {
	my ($self) = @_;
	$self->{abbreviateMonths} = 1;
}

sub useShortDayNames {
	my ($self) = @_;
	$self->{abbreviateDays} = 1;
}


## informational

sub isAMorPM {
	my ($self) = @_;
	return if ($self->{hourType} == 24);
	$self->getHours() unless $self->{am_or_pm};
	return $self->{am_or_pm};
}

sub getSeconds {
	my ($self) = @_;
	return sprintf("%02d", $self->{elements}->[0]);
}

sub getMinutes {
	my ($self) = @_;
	return sprintf("%02d", $self->{elements}->[1]);
}

sub getHours {
	my ($self) = @_;
	if ($self->{hourType} == 12){
		my $hours = $self->{elements}->[2];
		if ($hours == 12){
			$self->{am_or_pm} = "p.m.";
			return 12;
		}
		elsif ($hours == 0) {
			$self->{am_or_pm} = "a.m.";
			return 12;
		}
		elsif ($hours < 12){
			$self->{am_or_pm} = "a.m.";
			return $hours;
		}
		elsif ($hours > 12){
			$self->{am_or_pm} = "p.m.";
			return $hours - 12;
		}
	}
	return $self->{elements}->[2];
}

# GMT offsets

# ... by hours
sub getGMTOffsetHours {
	my ($self) = @_;
	return $self->{gmt_offset_hours};
}	

# ... by minutes
sub getGMTOffsetMinutes {
	my ($self) = @_;
	return $self->{gmt_offset_minutes};
}

# and finally a formatted offset
sub getGMTOffset {
	my ($self) = @_;
	my $gmt_offset = abs($self->{gmt_offset_hours});
	my $sign = "";
	$sign = "-" if ($gmt_offset > $self->{gmt_offset_hours});
	return sprintf("%s%02d00", ($sign, $gmt_offset));
}

sub getDayOfMonth {
	my ($self) = @_;
	return $self->{elements}->[3];
}

sub getMonth {
	my ($self) = @_;
	if ($self->{abbreviateMonths} == 1){
		return (MONTHS->[$self->{elements}->[4]] =~ /(...)/);	
	}
	return MONTHS->[$self->{elements}->[4]];
}

sub getNumericMonth {
	my ($self) = @_;
	return $self->{elements}->[4] + 1;
}

sub getMonthIndex {
	my ($self) = @_;
	return $self->{elements}->[4];
}

sub getFullYear {
	my ($self) = @_;
	return (1900 + $self->{elements}->[5]);
}

sub getYear {
	my ($self) = @_;
	return sprintf("%02d", ($self->{elements}->[5] % 100));
}

sub getDayOfWeek {
	my ($self) = @_;
	if ($self->{abbreviateDays} == 1){
		return (DAYS->[$self->{elements}->[6]] =~ /(...)/);	
	}
	return DAYS->[$self->{elements}->[6]];
}

sub getDayOfWeekIndex {
	my ($self) = @_;
	return $self->{elements}->[6];
}

sub getDayOfYear {
	my ($self) = @_;
	return $self->{elements}->[7];
}

### overloaded interfaces

sub clone {
	my ($self) = @_;
	return $self->unpack($self->pack());
}

## serialization

sub pack {
	my ($self) = @_;
	return $self->{internal};
}

sub unpack {
	# this is an alternate constructor 
	my ($class, $packed_string) = @_;
	return _setTime($class->new(), $packed_string);
}

## printing

sub toString { 
	# this could be more
	# robust to take advantage of
	# the module configurations
	my ($self) = @_; 
	return $self->{formatter}->($self) if $self->{formatter};
	return scalar localtime($self->{internal}); 
}

# return the unmolested object string
sub stringValue {
	my ($self) = @_;
	return overload::StrVal($self);
}

### overloaded operators

# Addition and Subtraction operators are 
# best used in conjunction with a Data object that
# has been create using the createTimeInterval 
# constructor. 

sub add {
	my ($left, $right) = @_;
	(UNIVERSAL::isa($left, "Date::Formatter") && UNIVERSAL::isa($right, "Date::Formatter")) 
		|| die "Illegal Operation : Cannot add a date object to a non-date object.";
	return _setTime($left->clone(), $left->{internal} + $right->{internal});
}

# sub addEqual {
# 	my ($left, $right) = @_;
# 	((ref($left) eq "Date::Formatter") && (ref($right) eq "Date::Formatter")) || die "IllegalOperation : IllegalOperation : Cannot add a date object to a non-date object.";
# 	return $left->_setTime($left->{internal} + $right->{internal});
# }

sub subtract {
	my ($left, $right) = @_;
	(UNIVERSAL::isa($left, "Date::Formatter") && UNIVERSAL::isa($right, "Date::Formatter"))  
		|| die "Illegal Operation : Cannot subtract a date object from a non-date object.";
	return _setTime($left->clone(), $left->{internal} - $right->{internal});
}

# sub subtractEqual {
# 	my ($left, $right) = @_;
# 	((ref($left) eq "Date::Formatter") && (ref($right) eq "Date::Formatter")) || die "IllegalOperation : Cannot subtract a date object from a non-date object.";
# 	return $left->_setTime($left->{internal} - $right->{internal});
# }

# compare two dates
sub compare {
	my ($left, $right) = @_;
	(UNIVERSAL::isa($left, "Date::Formatter") && UNIVERSAL::isa($right, "Date::Formatter")) 
		|| die "Illegal Operation : Cannot compare a date object to a non-date object.";
	return ($left->{internal} <=> $right->{internal});
}

sub equal {
	my ($left, $right) = @_;
	return ($left->compare($right) == 0) ? 1 : 0;
}

sub notEqual {
	my ($left, $right) = @_;
	return ($left->equal($right)) ? 0 : 1;
}


1;

__DATA__

1;

__END__

=head1 NAME

Date-Formatter - A simple Date and Time formatting object 

=head1 SYNOPSIS

  use Date::Formatter;
  
  # create a Date::Formatter object with the current date and time.
  my $date = Date::Formatter->now();
  
  # create a formatter routine for this object
  # see formatter mini-language documentation below
  $date->createDateFormatter("(hh):(mm):(ss) (MM)/(DD)/(YYYY)");   
  
  print $date; # print date in this format -> 12:56:03 4/12/2004
  
  # get the formatter for use with other objects
  my $formatter = $date->getDateFormatter();
  
  # create an interval of time
  my $interval = Date::Formatter->createTimeInterval(years => 1, days => 2, minutes => 15);
  
  # re-use the formater from above
  $interval->setDateFormatter($formatter);
  
  print $interval; # print date in this format -> 12:56:03 4/12/2004 
  
  # use overloaded operators
  my $future_date = $date + $interval;
  
  # sort the dates (again with the overload operator)
  my @sorted_dates = sort { $a <=> $b } ($date, $interval, $future_date);

=head1 DESCRIPTION

This module provides a fast and very flexible mini-language to be used in formatting dates and times. In order to make that useful though, we had to make a fully functioning date & time object. This object looks and smells much like the Java and Javascript Date object on purpose. We also overloaded a number of operators to allow date addition and subtraction as well as comparisons.

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>, B<now> 

C<new> or C<now> will create a B<Date::Formatter> object with the current time.

=item B<createTimeInterval (%date_info)>

This is a method for creating intervals of time. This is best used with the overloaded versions of the +, +=, - and -= operator to increment and decrement another B<Date::Formatter> object.

Accepts the following named arguments:

 years (365 days)
 leap years (366 days)
 months (assumes 30 days)
 weeks
 days
 hours
 minutes
 seconds

B<NOTE:> 

This can also be used to set a time sometime past the epoch, but that is not terribly useful. Except maybe to pass in nothing and get the date of the epoch on your current system.

=item B<refresh>

Occasionally you will want to refresh the time to be the current time. This would allow a B<Date::Formatter> object to be used over a long period of time.

=back

=head2 Formatted Output Methods

=over 4

The formatted output methods are means of customizing the string output of the B<Date::Formatter> object. The C<createDateFormatter> is at the heart of this group, it implements a mini-language for formatting dates. 

B<NOTE:> 

That the internal parser in C<createDateFormatter> has been optimized to make this a very usable operation, as it will be one of the most common uses of this object.

=item B<createDateFormatter ($format_string)>

All date tokens must be enclosed in parantheses (or some other seperator for which you must provide the regular expression that C<split> will use to tokenize the string). The formatter will use the current settings for 12 or 24 hour clock as well as the abbreviated day and month names. Here is a description of the available tokens and what they output:

 hh is hours
 mm is minutes
 ss is seconds
 single M will print the name of the month
 MM will print the numeric month
 single D will print the day by name
 DD will print the numeric day of the month
 YY will print the two digit year
 YYYY will print the four digit year 
 T will print either "a.m." or "p.m." if you have chosen to use the 12 hour clock
 O will print the GMT offset in hours in the standard format

Any character not included in here is deamed a seperator and will pass into the output unchanged.
Here are some format strings and some example output they would produce:

 (hh):(mm):(ss) (MM)/(DD)/(YYYY)
 ex: 12:56:03 12/9/2002
 
 (hh):(mm) (D), (M) (DD), (YYYY)
 ex: 12:56 Monday, December 9, 2002
 
 (hh):(mm) (DD)-(MM)-(YY)
 ex: 12:56 9-12-02
 
 (MM)/(DD)/(YYYY) (hh):(mm):(ss)
 ex: 12/9/2002 12:56:03
 
 (MM).(DD).(YYYY) (hh):(mm):(ss) (T) (O)
 ex: 12.9.2002 12:56:03 p.m. -0500	

Remember it can be as complex as you want it to be, there is no restrictions:

 Today is the (DD) th of (M)
 the Year of our Lord (YYYY)
 at (ss) seconds past 
	(mm) minutes past 
         the hour of (hh)

 Today is the 9th of December 
 the Year of our Lord 2002
 at 03 seconds past 
	56 minutes past 
	   the hour of 12

here is a format that will exactly mimic the default date format
(you must set the date object to C<useShortNames> and C<use24HourClock>)

 (D) (M) (DD) (hh):(mm):(ss) (YYYY)
 ex: Mon Dec  9 13:02:10 2002

=item B<getDateFormatter>

returns the formatter subroutine, so you can share between multiple B<Date::Formatter> objects if you like.

=item B<setDateFormatter ($func)>

=back

=head2 Configuration methods

Most of the configuration methods are pretty self explanitory. They act only on the current B<Date::Formatter> object instance they are applied against.

=over 4

=item B<use24HourClock>

=item B<use12HourClock>

=item B<useLongNames>

=item B<useLongMonthNames>

=item B<useLongDayNames>

=item B<useShortNames>

=item B<useShortMonthNames>

=item B<useShortDayNames>

=back

B<NOTE:> Short names means we show the first 3 letters of the word only.

=head2 Informational Methods

The informational method are also self-explanitory, and in cases where further clarification is either neccesary or helpful it is provided.

=over 4

=item B<isAMorPM>

Returns 'a.m.' or 'p.m.' respectively.

=item B<getSeconds>

=item B<getMinutes>

=item B<getHours>

=item B<getGMTOffsetHours>

=item B<getGMTOffsetMinutes>

=item B<getGMTOffset>

This method formats the GMT hour offset in the standard way.

 ex: -0500 for EST

=item B<getDayOfMonth>

=item B<getMonth>

=item B<getNumericMonth>

=item B<getMonthIndex>

=item B<getFullYear>

=item B<getYear>

=item B<getDayOfWeek>

=item B<getDayOfWeekIndex>

=item B<getDayOfYear>

=back

=head2 Overloaded Operators

Addition and subtraction operators are best used in conjunction with a B<Date::Formatter> object that has been create using the C<createTimeInterval> pseudo-constructor. 

=over 4

=item B<add>

=item B<subtract>

These methods overload the + and - operators respectively.

=item B<toString>

A C<toString> method is implemented, and used to overload the '""' stringification operator.

=item B<compare>

Compare two dates using the compare method or the overloaded E<lt>=E<gt> operator.

=item B<equal>

Compare two dates using the compare method or the overloaded == operator.

=item B<notEqual>

The inverse of C<equal>.

=back

=head2 Misc Methods

=over 4

=item B<clone>

Optimized C<clone> method, this is a good way to make multiple objects all with the same time. 

=item B<pack>

=item B<unpack>

The normal C<pack> and C<unpack> methods are provided and will serialize the B<Date::Formatter> object to a 32 bit integer which represents the number of seconds from the epoch (a.k.a. UnixTime).

=item B<stringValue>

Returns the non-overloaded string representation of the object.

=back

=head1 LIMITATIONS

The Date::Formatter class is epoch limited. Below is a note about this from perl.com.

 "... on most current systems, epochs are represented by a 32 bit signed integer, 
 which only lets you represent datetimes with a range of about 136 years.  On most 
 UNIX systems currently in use, this means that the latest date you can represent 
 right now is sometime in the year 2038, and the earliest is around 1902."

=head1 TO DO 

Possibly incorporate a timer class with this as well, with C<start> and C<stop> methods.

Using date formatters on time intervals does not always make sense, as it will just give you a representation of the interval past after the epoch. Possibly consider an alternate format for intervals. This would likely require some reworking of the way intervals are handled so it is only an idea for now.

=head1 BUGS

None that I am aware of. The code is pretty thoroughly tested (see L<CODE COVERAGE> below) and is based on an (non-publicly released) module which I had used in production systems for over 2 years without incident. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, below is the B<Devel::Cover> report on this module's test suite.

 ---------------------------------------- ------ ------ ------ ------ ------ ------ ------
 File                                       stmt branch   cond    sub    pod   time  total
 ---------------------------------------- ------ ------ ------ ------ ------ ------ ------
 /Date/Formatter.pm                        100.0   96.2   62.2  100.0  100.0  100.0   94.5
 t/10_Date_Formatter_test.t                100.0   50.0   33.3    n/a    n/a   85.3   92.0
 t/20_Date_Formatter_overloads_test.t      100.0    n/a    n/a  100.0    n/a    3.7  100.0
 t/30_Date_Formatter_formatter_test.t      100.0    n/a    n/a  100.0    n/a   19.7  100.0
 t/40_Date_Formatter_serialization_test.t  100.0    n/a    n/a    n/a    n/a    0.6  100.0
 t/50_Date_Formatter_interval_test.t       100.0    n/a    n/a    n/a    n/a    1.1  100.0
 ---------------------------------------- ------ ------ ------ ------ ------ ------ ------
 Total                                     100.0   92.9   60.4  100.0  100.0  100.0   95.5
 ---------------------------------------- ------ ------ ------ ------ ------ ------ ------

=head1 SEE ALSO

The accessor interface to this module was inspired by and at times directly ripped off from the Javascript and Java Date objects.

For serious date/time involved work, skip my module and go straight to the
DateTime project at L<http://datetime.perl.org>. Don't even waste your time 
with anything else.

Also here is a good article on the state of Perl's date-time world. It is
a glimpse into the chaos - L<http://www.perl.com/pub/a/2003/03/13/datetime.html>.

Below is a list of other Date/Time modules I have looked over in the past, and my opinions regarding the differences between them and my module here. 

=over 5

=item B<Class::Date>

This module seems pretty nice, I have never used it. It is much more ambitious than my module, but in my opinion provides inferior formatting capabilties.

=item B<Date::Simple>

If you have to manipulate just dates (it doesnt handle time), then this is a pretty good module. It provides an XS as well as a Pure Perl version. 	

=item B<Time::Format>

This module is available as both an XS or a Pure perl version. It provides a funky global hash which can be used to easily format a UNIX time value. It does seem quite extensive, and is a nice way of going about this. But it is not OO at all, which is much of where it differs from my module.

=item B<Date::Format>

A pretty nice formatting module, but purely functional in style. Not that thatis bad, just that its not the same as our OO version.	

=item B<Time::Object>

=item B<Time::localtime>

Are both wrappers/helpers/extensions around the C<localtime> and C<gmttime> functions.

=back

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

