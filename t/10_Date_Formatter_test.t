#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 29;

BEGIN { 
    use_ok('Date::Formatter')
}

can_ok("Date::Formatter", 'new');
can_ok("Date::Formatter", 'now');

# get the current date
my $date = Date::Formatter->now();
isa_ok($date, 'Date::Formatter');

# get a date interval
my $interval = Date::Formatter->createTimeInterval(minutes => 10);
isa_ok($interval, 'Date::Formatter');

# pack the interval to find out how many seconds it is
can_ok($interval, 'pack');
cmp_ok($interval->pack(), '==', 600, '... this is how many seconds the interval is');
is($interval->isAMorPM(), "p.m.", '... it should be p.m.');

# add the date to the interval
my $later_date = $date + $interval;
# now check that the later date actually 10 minutes later
cmp_ok((($date->getMinutes() + 10) % 60), '==', $later_date->getMinutes(), '... its 10 minutes later');

# check the refresh function
my $refreshed_date = Date::Formatter->new();
isa_ok($refreshed_date, 'Date::Formatter');

# sleep for a second
sleep 1;
# and make sure a second has passed
cmp_ok((($refreshed_date->getSeconds() + 1) % 60), 
		 '<=', 
		 $refreshed_date->refresh()->getSeconds(), 
		 '... its 1 second later'); 

# now check the 24 hour settings
my $hour = $date->getHours();
my $is_am = ($date->isAMorPM() eq 'a.m.') ? 1 : 0;
$date->use24HourClock();
cmp_ok((($is_am || $hour == 12) ? $hour : $hour + 12), '==', $date->getHours(), '... our 24 hour clock is good');
# this should now return nothing
ok(!defined($date->isAMorPM()), '... this is undefined');

# and back to the 12 hour clock
$date->use12HourClock();
cmp_ok($hour, '==', $date->getHours(), '... our 12 hour clock is good');

# test the GMT stuff
my ($gmt_minutes, $gmt_hours) = (gmtime($date->pack()))[1, 2];
# we need to do this with the 24 hour clock
$date->use24HourClock();
cmp_ok($date->getGMTOffsetHours(), '==', ($date->getHours() - $gmt_hours), 
	   '... the GMT hours offset');
cmp_ok($date->getGMTOffsetMinutes(), '==', ($date->getMinutes() - $gmt_minutes), 
	   '... the GMT minutes offset');

is($date->MONTHS()->[$date->getMonthIndex()], $date->getMonth(), '... these should match');

is($date->DAYS()->[$date->getDayOfWeekIndex()], $date->getDayOfWeek(), '... these should match');

cmp_ok($date->getDayOfYear(), '==', (localtime)[7], '... test day of year');

# clone function
can_ok($date, 'clone');
isnt($date->stringValue(), $date->clone()->stringValue(), '... these object arent the same instance');

# get a pristine date object to test hours with

my $date2 = Date::Formatter->new();
$date2->use24HourClock();

my $hours = $date2->getHours();
$date2->use12HourClock();

cmp_ok($date2->add(Date::Formatter->createTimeInterval(hours => 
											(($hours == 12) ?
												12
												:	
												12 - $hours)))->getHours(),
		'==', 12, '... this should push it to 12');
is($date2->add(Date::Formatter->createTimeInterval(hours => 
											(($hours == 12) ?
												12
												:	
												12 - $hours)))->isAMorPM(),
		'p.m.', '... this should be p.m.');
		
cmp_ok($date2->subtract(Date::Formatter->createTimeInterval(hours => $hours))->getHours(),
		'==', 12, '... this should push it to 12');	
is($date2->subtract(Date::Formatter->createTimeInterval(hours => $hours))->isAMorPM(),
		'a.m.', '... this should be a.m.');	
		
cmp_ok($date2->subtract(Date::Formatter->createTimeInterval(hours => abs((($hours == 12) ?
												12
												:	
												12 - $hours) - 1)))->getHours(),
		'==', 11, '... this should push it to 11');	
is($date2->subtract(Date::Formatter->createTimeInterval(hours => abs((($hours == 12) ?
												12
												:	
												12 - $hours) - 1)))->isAMorPM(),
		'a.m.', '... this should be a.m.');							
	
cmp_ok($date2->add(Date::Formatter->createTimeInterval(hours => ((($hours == 12) ?
												12
												:	
												12 - $hours) + 1)))->getHours(),
		'==', 1, '... this should push it to 1');	
is($date2->add(Date::Formatter->createTimeInterval(hours => ((($hours == 12) ?
												12
												:	
												12 - $hours) + 1)))->isAMorPM(),
		'p.m.', '... this should be p.m.');		

