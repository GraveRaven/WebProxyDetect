#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
require LWP::UserAgent;

my $helptext = 
"Usage: $0 <options> URLs
    -h  --help      This help text
    -f  --forwards  The number of forwards to test for (Default: 3)
    -m  --method    The method to use (Default: OPTIONS)
    -u  --url       A list of urls to test
    
    Output format: Forwards: <number of forwards> -- <status code> -- <VIA header> -- <ALLOW header> -- <Server>";

my $ua = LWP::UserAgent->new(requests_redirectable => ['GET', 'HEAD', 'OPTIONS'], timeout => 5);
$ua->ssl_opts(verify_hostname => 0);
my $forwards = 3;
my @urls;
my $method = "OPTIONS";
my $help;

GetOptions('forwards=i' => \$forwards, 'method=s' => \$method, 'url=s' => \@urls, 'help' => \$help);

if($help){
    print $helptext, "\n";
    exit;
}

foreach (@ARGV){
    push(@urls, $_);
}

if(!@urls){
    print "Usage: $0 -u <URL>\n";
    exit -1;
}

LOOP: foreach my $url (@urls){
    print "$url\n";
    my $found = 0;
    my $code_last = "";
    my $opt_last = "";
    my $server_last = "";

    for my $i (reverse(0..$forwards)){
        my $header = ['Max-Forwards' => $i];
        my $req = HTTP::Request->new($method, $url, $header);
        my $resp = $ua->request($req);

        my $code = $resp->status_line;
        
        if($code =~ /timeout/ && $i == 3){ next LOOP; }

        my $opt = $resp->header('Allow') || "OPTIONS not supported";
        my $server = $resp->header('Server') || "Unknown server";
        my $via = $resp->header('Via') || "No via";
        my $cache = $resp->header('Cache-Control') || "No Cache-Control";
        my $cookie = $resp->header('Set-Cookie') || "No Set-Cookie";
        my $age = $resp->header('Age') || "No Age";

        if($via ne "No via" || 
            ($code_last && ($code ne $code_last)) || 
            ($opt_last && ($opt ne $opt_last)) ||  
            ($server_last && ($server ne $server_last)) ||
            ($age ne "No Age")){
          $found = 1;
        } 
        
        if($cache ne "No Cache-Control"){
            $found = 1;
            $cache = "Cache-Control set";
        }

        if($cookie =~ "ISAWPLB"){
            $found = 1;
            $cookie = "ISAWPLB cookie set";
        }

        
        $code_last = $code;
        $opt_last = $opt;
        $server_last = $server;

        print "Forwards: $i -- $code -- $via -- $cache -- $cookie -- $age -- $opt -- $server\n";
    } 

    if($found){print "Possible proxy detected\n";}
    print "\n";
}
