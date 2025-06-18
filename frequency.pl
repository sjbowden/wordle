#!/usr/bin/perl

use strict;

my %frequency = ();

foreach my $char ("a".."z"){
  $frequency{$char} = 0;
}

open FILE, "answers.txt" or die "Can't open answers.txt\n";
while(<FILE>){
  foreach my $char ("a".."z"){
    if(m/$char/){
      $frequency{$char}++;
    }
  }
}
close FILE or die;

foreach my $char (sort { $frequency{$b} <=> $frequency{$a} } keys %frequency){
  print "$char ".$frequency{$char}."\n";
}

# best word is ORATE
