package Blop::Test;
use strict;
use warnings;

my $test = 0;
my $fail = 0;

sub import {
    no strict "refs";
    my $caller = caller;
    *{$caller . "::ok"} = \&ok;
    *{$caller . "::done_testing"} = \&done_testing;
}

sub ok {
    my ($pass, $desc) = @_;
    if (!$pass) {
        print "not ";
        $fail++;
    }
    print "ok " . ++$test;
    print " - " . $desc if $desc;
    print "\n";
}

sub done_testing {
    print "1..$test\n";
    if ($fail) {
        printf "# Looks like you failed %s test%s of %d run.\n",
            $fail, $fail == 1 ? "" : "s", $test;
    }
    exit $fail;
}

1;
