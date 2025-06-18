#!/usr/bin/perl

use strict;                      # keep us honest
use Util;                        # command line parsing
use List::MoreUtils qw(uniq);    # scalar context, returns number of unique elements in list

my $answers    = []; # all possible answers
my $allwords   = []; # all words allowed as guesses
my $words      = {}; # all possible answers as hierarchal hash

my $characters = {}; # valid characters
my $freq       = []; # valid characters sorted by frequency
my %wordsfound = (); # words found by searching

my %knownchars = {}; # known characters

use vars qw(
             $opt_solve
             $opt_debug
          );

&Util::parse_opts("debug|d",    # enable debug messages
                  "solve|s",    # solve
                 );

$opt_solve = 1 if(defined($opt_debug));

if(defined($opt_debug)){
  eval "use Data::Dumper;";    # print out complex data structures (for debug)
  die "couldn't load module : $!n" if ($@);
}

foreach my $char ("a".."z"){
  $characters->{$char} = 1;
}

open FILE, "answers.txt" or die "Can't open answers.txt\n";
while(<FILE>){
  #chomp;
  s/[\r\n]+$//; # remove new lines and carriage returns
  push @$answers, $_;
  push @$allwords, $_;
}
close FILE or die;

open FILE, "guesses.txt" or die "Can't open guesses.txt\n";
while(<FILE>){
  s/[\r\n]+$//; # remove new lines and carriage returns
  push @$allwords, $_;
}
close FILE or die;

while(1){
  &create_dict;
  
  # find letter frequency
  &calculate_frequency;

  %wordsfound = ();
  
  splice(@$freq, 0, 0, keys(%knownchars));
  
  # generate guess based on letter frequency

  &process($words,"",0,@$freq);
  
#  my @guess = splice(@$freq, 0, 4);
#  foreach my $char (@$freq){
#    push @guess, $char;
#    
#    &process($words,"",0,@$freq);
#    if(keys(%wordsfound) > 0){
#      last;
#    }
#  }
  
  print "\nTry one of these words:\n" if(defined($opt_solve));
  my $count = 0;
  foreach my $word (sort { $wordsfound{$a} <=> $wordsfound{$b} } keys %wordsfound){
    # sort by # of unique letters?
    print "$word : "         if(defined($opt_solve));
    print $wordsfound{$word} if(defined($opt_solve));
    print "\n"               if(defined($opt_solve));;
    $count++;
  }
  print "$count answers left\n" if(!defined($opt_solve));


  # try guess
  my $guess;
  while(1){
    print "\nWhich word did you try?\n";
    $guess = <STDIN>;
    
    chomp($guess);
    
    if(grep(/^$guess$/,@$allwords)){
      last;
    } else {
      print "Not a valid word, try again!\n";
    }
  }
  my $result;

  while(1){
    print "\nWhat is the result (X for right place, x for right letter, . for incorrect)?\n";
    $result = <STDIN>;
    
    chomp($result);

    if($result =~m/^[Xx.]{5}$/){
      last;
    } else {
      print "Not a valid result, try again!\n";
    }
  }
  
  # add error checking
  
  # prune dictionary
  &prune_dict($guess,$result);
  
  if(@$answers == 1){
    print "Answer is: ".$answers->[0]."\n" if(defined($opt_solve));
    print "Only 1 answer left\n" if(!defined($opt_solve));
    last;
  }
}



######################################################################
# Subroutines
######################################################################

sub calculate_frequency {
  my %charcount = ();
  $freq = [];
  
  foreach my $char (keys %$characters){
    $charcount{$char} = 0;
  }
  
  foreach my $word (@$answers){
    foreach my $char (keys %$characters){
      if($word =~m/$char/){	
	$charcount{$char}++;
      }
    }
  }
  print "Character distribution\n" if(defined($opt_debug));
  foreach my $char (sort { $charcount{$b} <=> $charcount{$a} } keys %charcount){
    if($charcount{$char} != 0){
      push @$freq, $char;
      $characters->{$char} = $charcount{$char};
      print "$char ".$charcount{$char}."\n" if(defined($opt_debug));
    } else {
      delete $characters->{$char};
    }
  }
}

sub create_dict {
  $words = {};
  
  foreach my $word (@$answers){
    &insert_to_dict($word);
  }

}

# Add words to a hash of hashes
#
sub insert_to_dict {
  my @word = split //, shift;  # split incoming word

  my $hash = $words; # $hash is temporary pointer to current level of hash structure
  
  # walk through letters of words and add to hash structure
  foreach my $letter (@word){
    if(!exists($hash->{$letter})){  # if letter not in hash, add it
      $hash->{$letter} = {};
    }
    $hash = $hash->{$letter}; # use current letter to descend into hash
  }
  
  $hash->{"done"} = 1;        # when word is done, add done sentinel
}

# Remove words that don't match clues
#
sub prune_dict {
  my $guess = shift;
  my $response = shift;
  my $oarray = $answers;
  my $narray = [];
  
  foreach my $charnum (0..4){
    my $rep  = substr($response,$charnum,1);
    my $char = substr($guess,   $charnum,1);
    $knownchars{$char} = 1 if($rep eq "x");
    $knownchars{$char} = 1 if($rep eq "X");

    # this hash is unknown search space
    delete $characters->{$char}; #delete known characters no matter the location
  }
  
  foreach my $word (@$oarray){
    print "Evaluating $word\n" if(defined($opt_debug));
    
    my $add    = 1;
    
    foreach my $charnum (0..4){
      my $rep  = substr($response,$charnum,1);
      my $char = substr($guess,   $charnum,1);
      
      print "processing $char\n" if(defined($opt_debug));
      
      # remove words with characters not in solution
      # don't remove if already in answer (i.e. for second character)
      if($rep eq "." && $word =~m/$char/ && !exists($knownchars{$char})){
	# delete word
	$add = 0;
	last;
      }
      
      # remove words that don't have a character known to be in the solution
      if($rep eq "x" && $word !~m/$char/){
	# delete word
	$add = 0;
	last;
      }
      
      # remove words that have a known character in the wrong place
      my $tempstring = ".....";
      substr($tempstring,$charnum,1,$char);
      if($rep eq "x" && $word =~m/^$tempstring$/){
	# delete word
	$add = 0;
	last;
      }
      
      # remove words with a known character in the wrong place (duplicate letter case)
      my $tempstring = ".....";
      substr($tempstring,$charnum,1,$char);
      if($rep eq "." && $word =~m/^$tempstring$/ && exists($knownchars{$char})){
	# delete word
	$add = 0;
	last;
      }
      
      # remove words that don't have a known character in the correct place
      my $tempstring = ".....";
      substr($tempstring,$charnum,1,$char);
      if($rep eq "X" && $word !~m/^$tempstring$/){
	# delete word
	$add = 0;
	last;
      }
    }
    
    if($add){
      push @$narray, $word;
    }
  }
  
  $answers = $narray;
}

# Test all letter combinations against words from dictionary
#
sub process {
  my $hash = shift;
  my $str = shift;
  my $lvl = shift;
  my @ary = @_;
  my %used = ();
  my $j;
  
  # keep track of how many times this function is called
  #$globalcount++;
  
  # if legal word, add to result hash
  if(exists($hash->{'done'})){  # if there is a 'done' sentinel, then it is a legal word
    $wordsfound{$str} = &word_value($str);
  }
  
  # this function handles the branching of the search tree
  #
  foreach($j=0;$j<@ary;$j++){         # loop through remaining letters
    my @copy = @ary;                  # copy the array
    my $letter = $ary[$j];            # pick a letter out of the array
    
    if(exists($hash->{$letter})){     # if it exists, then recurse
      process($hash->{$letter}, $str.$letter, $lvl+1,@copy);
    } # end if
  } # end foreach
} # end sub process

sub word_value {
  my $word = shift;
  my $value = 0;

  my @letters = split //, $word;
  foreach my $letter (@letters){
    $value += $characters->{$letter};

    if(exists($knownchars{$letter})){
      $value += 10000;
    }
  }

  if(scalar(uniq(@letters)) == 5){
    $value += 10000;
  }

  # add value for known letters
  
  return $value;
}
