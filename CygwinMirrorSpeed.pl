#!/usr/bin/perl
use strict;
use warnings;

=pod

=head1 NAME

CygwinMirrorSpeed.pl

=head1 DESCRIPTION

Tests for the fastest mirror to your current location.
Skips mirrors with excessive latency.
Downloads a standard file on the host for up to 2 seconds to calculate the download rate.
Produces a list of hosts sorted by download rate and noting the latency.

High download rates are good.  Low latentcy is good.

=head1 REQUIRES

=over

=item *
Cygwin or Linux

=item *
perl

=over

=item *
Time::HiRes

=item *
LWP::UserAgent

=item *
Net::Ping

=back

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017, by Jeff Morton.

This is free software, licensed under:

  GNU GENERAL PUBLIC LICENSE Version 3

Details of this license can be found within the 'LICENSE' text file.

=cut 

our $VERSION = '1.00';

use LWP::UserAgent;
use Net::Ping;
use Time::HiRes qw(time);

$|=1;
our $verbose=0;
exit(usage()) if scalar grep(/-+help/,@ARGV);
$verbose++ if scalar grep(/-+verbose/,@ARGV);

# Get mirror list
my $url_mirrors="http://cygwin.com/mirrors.lst";
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
my $response = $ua->get($url_mirrors);
die $response->status_line unless ($response->is_success);


# Parse mirror list and ping hosts
my @mirrors = map { {input => $_} } split(/\r?\n/,$response->decoded_content);
my %mirrors;
my $p = Net::Ping->new("syn",3);
my $i = 0;
my $j = scalar @mirrors;
$p->hires(1);
foreach my $m (@mirrors) {
	$i++;
	($m->{url},$m->{name},$m->{region},$m->{location},my $junk) = split(/\;/,$m->{input},5);
	print "OOPS LINE HAS JUNK: $junk\n" and die if $junk;
	printf "\rPing %d/%d", $i, $j;

	$m->{url} =~ m{([a-z]+)://(.*?)(:(\d+))?/};
	$m->{protocol} = $1;
	$m->{host} = $2;
	$m->{port} = $4 ? $4 : scalar(getservbyname($1, "tcp"));

	$mirrors{$m->{host}} = $m;

	printf "\nPing %30s", $m->{host} if $verbose;
	$p->port_number($m->{port});
	$p->ping($m->{host});

	while (my ($host,$rtt,$ip,$junk) = $p->ack) {
		printf " took %3.0fms.\n", $rtt*1000 if $verbose;
		$mirrors{$host}->{ping} = $rtt;
	}
}
print "\n";
if ($verbose) {
	printf "Ping exceeded 1s for %d of %d\n", scalar (grep {! defined $_->{ping}} @mirrors), scalar @mirrors;
}

# Fetch up to 2 seconds or 1M worth of the setup file from the test host.
my $file = "x86/setup.bz2";
our $starttime = time();
$ua->timeout(2);
$ua->max_size(1024*1024);
$ua->add_handler( response_data => sub {
		my($response, $a, $h, $data) = @_;
		die() if (time() - $starttime) > $a->timeout;
		return 1;
	});
$i=0;
$j=scalar grep {$_->{ping}} @mirrors;
foreach my $m (@mirrors) {
	$i++;
	next unless defined $m->{ping};
	printf "\rTest %d/%d", $i, $j;

	printf "\nTest %s://%s (%s,%s) ", 
		$m->{protocol}, $m->{host}, $m->{location} , $m->{region} if $verbose;

	my $url = $m->{url} . $file;
	$starttime = time();
	my $response = $ua->get($url, ':read_size_hint' => 4096);
	my $endtime = time();
	my $size = length $response->content;
	my $time = $endtime-$starttime;

	unless ($response->is_success) {
		printf "failed\n" if $verbose;
		$m->{bytes} = "failed";
		next;
	}

	
	$m->{time} = $time;
	$m->{bytes} = $size;
	$m->{rate} = $size / $time;
	$m->{kRate} = int($m->{rate} / 1024);

	printf "%3.1fkBps\n", $m->{rate} / 1024 if $verbose;
}

my @sorted = grep {$_->{kRate}} sort {($a->{rate}||0) <=> ($b->{rate}||0)} @mirrors;

printf "\nFound %d responsive hosts.\n\n", scalar @sorted;

map { printf("%8.1fkBps (%3.0fms) %s://%s (%s, %s)\n",
	$_->{rate} / 1024, $_->{ping} *1000,
	$_->{protocol}, $_->{host}, 
	$_->{location} , $_->{region}) } @sorted;

###############################################################################
#
#   usage - display documentation
#
sub usage {
	require Pod::Perldoc;
	Pod::Perldoc->run(args => [$0]);
}

