#!/usr/bin/perl

foreach $c1 ("a".."z"){
  next if($c1 =~m/[crteahf]/);
  foreach $c2 ("a".."z"){
    next if($c2 =~m/[crtehf]/);
    print "se${c1}a${c2}\n";
  }
}
