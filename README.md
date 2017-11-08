NAME

    CygwinMirrorSpeed.pl

DESCRIPTION

Tests for the fastest mirror to your current location. Skips mirrors
with excessive latency. Downloads a standard file on the host for up to
2 seconds to calculate the download rate. Produces a list of hosts
sorted by download rate and noting the latency.

High download rates are good. Low latentcy is good.

REQUIRES

*   Cygwin or Linux
*   perl
**   Time::HiRes
**   LWP::UserAgent
**   Net::Ping

COPYRIGHT AND LICENSE

This software is Copyright (c) 2017, by Jeff Morton.

This is free software, licensed under:

GNU GENERAL PUBLIC LICENSE Version 3

Details of this license can be found within the 'LICENSE' text file.
