#!/usr/intel/bin/perl -w
# -*- perl -*-
########################################################################
#
# Util.pm
#
# This module implements command line parsing and other generally
# useful routines.
#
# Original Author: Chris Jones
# Original Date: November 13, 1995
#
# Copyright (c) 1995, 1996, Intel Corporation
# Intel Proprietary
#
# RCS information:
#       $Author: chrisj $
#       $Date: 1997/09/04 22:38:41 $
#       $Revision: 1.20 $
#       $State: Exp $
#       $Locker:  $
#       $Header: /pdx/wmt/arch/src/perl5/Util/Util.pm,v 1.20 1997/09/04 22:38:41 chrisj Exp $
#
########################################################################

package Util;
use Exporter ();
use strict;
use vars qw($disable_env_vars $no_bad_args $disable_messages
	    $errors $warnings $version);

@Util::EXPORT_OK = qw(&parse_opts &find_file &tmpfile);
@Util::ISA = qw(Exporter);
$Util::version = $1 if ('$Version: 1.0.9 $' =~ m/\$Version\:\s*(\S+)/); #'

#
# This is yet another getopt routine in perl (but not *THE* yagrip.pl)
#
# Usage: parse_opts(@valid_opts)
#
# Where each item in @valid_opts is a string describing the syntax for
# a valid option.  If the option name has a ':' suffix, then the
# parser will expect that option to take an argument.  If the option
# name has a '--' suffix, then the parse will expect that option to
# take multiple arguments which are followed by a '--'
#
# Any items on the command line of the form VAR=<text> before any
# switches are encountered will cause the environment variable VAR to
# be set to <text>.
#
# Note: if multiple instances of the same switch are used, then an
# array will keep track of all argument for that switch.  See -ver
# below for an example.
#
# Example: parse_opts("-ver:","-c","-ms--")
#
# For @ARGV = -ver test -c -ms -ver junk -- -ver test2
# parse_opts would set the following global variabls:
#    $opt_ver = "test2"
#    @opt_ver = ("test","test2")
#    $opt_c = 1
#    @opt_ms = ("-ver","junk")
#
# This routine also allows you to define the package under which the
# option variables will be set.  If you prefix the option name with
# the package name followed by two colons (e.g. "-Mypack::ver"), then
# the variable $Mypack::opt_ver will be set insead of $main::opt_ver;
#
sub parse_opts
{
    my(@recognized) = @_;
    my($pkg, %abbr_for, %needs_arg, %needs_big, %call_sub, %package);
    my($save, $first, $found, $abbr, $tog, @tmp_args);
    my($var, $val);

    $Util::disable_env_vars = 0 if (! defined($Util::disable_env_vars));
    @main::main_args = ();

    # Note that we're modifiying the array elements in this loop.  We
    # set up some tables to save the info that we're stripping off of
    # each option (abbreviations, arg requirements, etc).
    #
    foreach (@recognized) {
	s/^-*//;
	if (s/(\w+)::([\-\w]+)/$2/) {   # Strip off any package declaration
	    $pkg = $1;
	} elsif (/([\-\w]+)/) {
	    $pkg = (caller)[0];
	}
	$abbr_for{"$2"} = $1 if s/([\-\w]+)\|-*([\-\w]*\w+)/$1/;
	$needs_arg{"$1"} = 1 if s/([\-\w]+):$/$1/;
	$needs_big{"$1"} = 1 if s/([\-\w]+)--$/$1/;
	$call_sub{"$1"} = 1 if s/([\-\w]+)&$/$1/;
	$package{"$1"} = $pkg if /([\-\w]+)/;
    }

    # Sort the lists now that we've stripped off the extra characters
    # so we look for "-ver" before "-v"
    #
    @recognized = reverse sort @recognized;
    while (@main::ARGV) {
	$save = $first = shift @main::ARGV;
	$found = $abbr = 0;
	$tog = 1;
	@tmp_args = ();

	if ($first =~ s/^-+//) {

	    # Try the simple case of a simple switch name match
	    #
	    foreach (@recognized) {
		$found = $abbr = $_, last
		  if (((! $Util::no_bad_args) && ($first =~ s/^$_//)) ||
		      ($Util::no_bad_args && ($first =~ s/^$_$//)));
	    }

	    # Check to see if it's an allowable abbreviation for a long
	    # switch name.
	    #
	    if (! $found) {
		foreach (keys %abbr_for) {
		    $found = $abbr_for{$_}, $abbr = $_, last
		      if (((! $Util::no_bad_args) && ($first =~ s/^$_//)) ||
			  ($Util::no_bad_args && ($first =~ s/^$_$//)));
		}
	    }

	    # OK, maybe it has a 'no_' prepended to a legal switch
	    # name
	    #
	    $tog = 0 if $first =~ s/^no_//;
	    
	    # Try the simple case of a simple switch name match
	    #
	    foreach (@recognized) {
		$found = $abbr = $_, last
		  if (((! $Util::no_bad_args) && ($first =~ s/^$_//)) ||
		      ($Util::no_bad_args && ($first =~ s/^$_$//)));
	    }

	    # Check to see if it's an allowable abbreviation for a long
	    # switch name.
	    #
	    if (! $found) {
		foreach (keys %abbr_for) {
		    $found = $abbr_for{$_}, $abbr = $_, last
		      if (((! $Util::no_bad_args) && ($first =~ s/^$_//)) ||
			  ($Util::no_bad_args && ($first =~ s/^$_$//)));
		}
	    }

	    # No luck, we don't know what to do with this switch.  Try
	    # to do some damage control.
	    #
	    if ((! $found) && (! $Util::no_bad_args)) {
		&warning("Unrecognized switch ignored: $first");
		push(@main::bad_args, $save);
		push(@main::bad_args, shift(@main::ARGV))
		  until ((! @main::ARGV) || ($main::ARGV[0] =~ /^-/));
		next;
	    }
	}

	# At this point, $found will be the option switch that was
	# recognized and $first will be any argument which was
	# "glued" to that option. (e.g. -Plw6, $found = P, $first = lw6)
	#
	if ($found) {
	    $pkg = $package{$found};
	    ($var = $found) =~ s/-/_/g;

	    eval("\$${pkg}::opt_$var = \$tog");

	    # If there's something attached to the option, but this
	    # option type doesn't take an argument, barf.
	    #
	    if ($first && (! $needs_arg{$found}) && ! $needs_big{$found}) {
		&error("Arg ($first) not expected for switch -$found");
	    }

	    # Arcane evals to set the perl variables which hold the
	    # value(s) of the option that was found
	    #
	    eval("\$${pkg}::opt_$var = \$first;
                  push(\@${pkg}::opt_$var,\$first)"), next
		      if ($first && $needs_arg{$found}); # Handles -Plw6

	    # Make sure an arg is present if this switch requires one
	    # and we didn't find one attached to the switch.
	    #
	    &error("Missing argument for switch -$found"), next
	      if ($needs_arg{$found} && ! (scalar(@main::ARGV)));
	    eval("\$${pkg}::opt_$var = shift \@main::ARGV;
                  push(\@${pkg}::opt_$var,\$${pkg}::opt_$var)"), next
		      if ($needs_arg{$found});           # Handles -P lw6
	    eval("\&${pkg}::opt_$var\(\$tog\);")
		if ($call_sub{$found});
	    @tmp_args = ($first)
		if ($first && $needs_big{$found});
	    if ($needs_big{$found}) {
		push(@tmp_args, shift @main::ARGV)
		    until ((! @main::ARGV) || 
			   ($main::ARGV[0] eq "-${found}-") ||
			   ($main::ARGV[0] eq "-${abbr}-") ||
			   ($main::ARGV[0] eq "--"));
		eval("\@${pkg}::opt_$var = \@tmp_args");
		eval("push(\@${pkg}::opt_${var}_all, [ \@tmp_args ])");
		unless (shift @main::ARGV) { # Get rid of trailing "--"
                    &warning("No closing '-${found}-' found for -$found");
                }
	    }
	}
	elsif ((! $Util::disable_env_vars) && $save =~ /(\w+)=(.*)$/) {
	    $var = $1;
	    $val = $2;
	    chop($ENV{$var}=`echo $val`); # Hmmmm...this is questionable
	}
	else {
	    push(@main::main_args, $save);
	}
    }
    @main::ARGV = @main::main_args;
}


# find_file
#
# This is a routine which will search a list of directories for a
# specific filename.  An extension may be provided which is appended
# to the end of filename if necessary.  
#
# Usage: find_file(filename, extension, searchpaths)
#
# Where filename is a string containing the file name.
#       extension is a string containing the extension (or is null/undef)
#       searchpaths is an array of strings, each containing one or
#                   more search directories separated by a ':'
#
# Example: find_file("test",".asm","/usr/local:/usr/local/bin","/fs2/e/chrisj")
#
# This will search for the following files in the following order:
#
#          /usr/local/test
#          /usr/local/test.asm
#          /usr/local/bin/test
#          /usr/local/bin/test.asm
#          /fs2/e/chrisj/test
#          /fs2/e/chrisj/test.asm
#
# If the subroutine is called within an array context, it returns all
# instances which match the search criteria (in order found).
# Otherwise it returns the full path of the first matching file found.
#
# NOTE: The current working directory "." is NOT searched by default.
# You need to specify it by including it in the search path list if
# you wish to search in the working directory.
#
sub find_file {
    my($fname, $ext, @paths) = @_;
    my($get_all) = wantarray;
    my(@foundfile, @allpaths) = ();

    # Weed out any undefined values passed in (e.g. environment vars)
    #
    @paths = grep(defined($_), @paths);
    
    # Build an array of all possible search paths to look in.  If the
    # filename starts with a '/', then we don't search the path list,
    # since the full path is specified (think unix PATH searches).
    #
    if ($fname !~ /^\//) {
	@allpaths = split(/:/,join(":",@paths));
    } else {
	@allpaths = ();
	push(@foundfile, "$fname$ext")
	  if (defined($ext) && -r "$fname$ext");
	push(@foundfile, "$fname") if (-r "$fname");
    }

    # Do the search through all possible search paths
    #
    while (@allpaths && ((! @foundfile) || ($get_all))) {
	$_ = shift(@allpaths);

	# See if we need to expand ~user or ~ into a real path
	#
	if ($_ =~ /^~(\w+)(.*)/) {
	    $_ = (getpwnam($1))[7] . $2;
	} elsif ($_ =~ /^~(.*)/) {
	    $_ = (getpwnam($ENV{USER}))[7] . $1;
	}

	# Now check to see if we can access a file by that name
	#
	push(@foundfile, "$_/$fname$ext")
	  if (defined($ext) && -r "$_/$fname$ext");
	push(@foundfile, "$_/$fname") if (-r "$_/$fname");
    }

    # Depending on whether the user is expecting only the first match
    # or all matches, we have to return different values.
    #
    if ($get_all) {
	return (0 == @foundfile) ? undef : @foundfile;
    } else {
	return (0 == @foundfile) ? undef : $foundfile[0];
    }
}


# tmpfile
#
# Return a valid path which can be used for creating temporary files.
#
sub tmpfile {
    my($fname) = @_;
    my($dir, @tmp_paths);

    # Search a list of paths to use for temp files.  We'll check the
    # environment variables first
    #
    push(@tmp_paths, $ENV{TMP}) if defined($ENV{TMP});
    push(@tmp_paths, $ENV{TEMP}) if defined($ENV{TEMP});
    push(@tmp_paths, '/tmp', '.');
    foreach (@tmp_paths) {
	$dir = $_, last if (defined($_) && (-d $_) && (-w $_));
    }

    # Get rid of trailing '/' in case environment var had one
    #
    chop($dir) if $dir =~ /\/$/;

    # Create new filename and save it in the list of known temp files.
    #
    $fname = $dir . "/" . $fname;
    push(@Util::tmpfiles, $fname);
    
    return $fname;
}


# Clean up any temporary files which we may have helped create
#
END {
    unlink(@Util::tmpfiles);
}


# warning
#
# Print and register a warning message
#
sub warning {
    my($msg) = @_;
    
    printf(STDERR "Warning: $msg\n") unless $Util::disable_messages;
    push(@Util::warnings, $msg);
}


# warning
#
# Print and register an error message
#
sub error {
    my($msg) = @_;
    
    printf(STDERR "Error: $msg\n") unless $Util::disable_messages;
    push(@Util::errors, $msg);
}


# Need a non-zero value for use/require to be happy when it includes
# this file
#
1;
__END__

=head1 NAME

Util - Perl module which contains generally useful routines

=head1 SYNOPSIS

    use Util;
    &Util::parse_opts(... option-descriptions ...);
    &Util::find_file(root, extension, search_path);


=head1 DESCRIPTION

The Util routines are provided to perform tasks which a large
percentage of Perl scripts must perform.  For example, virtually all
Perl scripts must parse command line switches.


B<parse_opts>

The option-descriptions specify which command line switches are
recognized by the calling program.  The parse_opts routine will use
this information to scan the command line and set variables
corresponding to any switch specified there.  Each valid command line
switch should have exactly one switch descriptor in the
option-descriptions list.

A switch descriptor contains the following information: the name of
the switch, an optional abbreviation of the switch name, an optional
package to which the switch value will be exported, and the type of
argument (if any) expected for the switch.

The values of command line switches are stored in scalar and/or
array variables named $opt_I<switch> or @opt_I<switch>.  If a switch
takes no argument, then $opt_I<switch> is set to 1.  If a switch takes
multiple arguments, then @opt_I<switch> contains the list of arguments
in the order they appeared on the command line.  If multiple instances
of a switch are specified on the command line, then $opt_I<switch>
contins the last value encountered, and @opt_I<switch> contains all of
the values in the order that they appeared on the command line.  The
$opt_I<switch> and @opt_I<switch> variables are created by default in
the same package as the routine which called &Util::parse_opts().  If
a switch is not encountered on the command line, then it's
corresponding $opt_I<switch> or @opt_I<switch> will remain undefined.

Any arguments on the command line in the form of VARIABLE=value will
cause the environment variable $VARIABLE to be set to B<value>.
I.e. C<$ENV{"VARIABLE"} = "value";> To disable this feature, set the
C<$Util::disable_env_vars> variable to non-zero before calling
&Util::parse_opts().

A descriptor for the B<-foo> command line switch which takes no
argment and stores it's value in $opt_foo would look like:

        "foo"

The 'B<:>' suffix is used to specify that a switch requires an
argument.  A descriptor for the B<-bar> command line switch which
takes a single argument and stores it's value(s) in $opt_bar and
@opt_bar would look like:

        "bar:"

The 'B<-->' suffix is used to specify that a switch requires multiple
arguments.  The argument list should be terminated with 'B<-->' on the
command line.  A descriptor for the B<-baz> command line switch which
takes multiple arguments and stores their values in @opt_baz would
look like:

        "baz--"

The 'B<&>' suffix is used to specify that the &opt_I<switch>
subroutine should be called as soon as this switch is found on the
command line.  This enables special processing of arguments for with
switch.  The &opt_I<switch> may modify @ARGV, keeping in mind that
$ARGV[0] is the argument immediately following the switch.  A
descriptor for the B<-jaz> command line switch which uses a subroutine
to handle it's own argument processing would look like:

        "jaz&"

An abbreviation for a switch can be supplied immediately after the
name of the switch by using the 'B<|>' separator.  The abbreviation
should appear before any argument type suffixes.  A descriptor for the
B<-timeout> switch which can be abbreviated as B<-t> and takes one
argument which is to be stored in $opt_timeout would look like:

        "timeout|t:"

An optional package name can be supplied which will force the
$opt_I<switch> and/or @opt_I<switch> variables to be declared in a
package other than the one from which parse_opts was called.  The
package name should prefix the option name along with the 'B<::>'
separator.  A descriptor for the B<-foo> switch which should set
$Baz::opt_foo instead of just $opt_foo would look like:

        "Baz::foo"

At most one package prefix, one abbreviation, and one type suffix may
be specified per command line switch.


B<find_file>

The B<root> parameter specifes the base filename which is being
searched for

The B<extension> parameter specifies an extension which may or may not
already be present on B<root>.

The B<search_path> parameter specifies a list of directories in which
to search for the file.  Each list element can be a single pathname or
a colon-separated list of path names.  Multiple colon-separated lists
are allowed, making it easy to combine several environment variables
which contain colon-separated lists of directories (a la $PATH).

Note that the "." directory will not be searched unless it is included
in the B<search_path> list.


=head1 RETURN VALUE

The B<parse_opts> routine returns the list of arguments which were not
command line switches.  These values also remain in the @ARGV array.

In a scalar context the B<find_file> routine returns the full path of
the file which was being searched for.  In an array context, it
returns the list of all complete paths at which the file was found.
If the file was not found, it returns B<undef> in either context.


=head1 EXAMPLES

If the script calls parse_opts as follows:

        &Util::parse_opts("help|h",
                          "d:",
                          "-ms--",
                          "Dpkg::ver|v:")

And the script is invoked as:

        script FOOBAR=baz -d 10 -ms this is -a test -- -v foobar -d 20

Then the following conditions hold:

        $ENV{"FOOBAR"} = "baz";
        $opt_help = undef;
        $opt_d = 20;
        @opt_d = (10, 20);
        @opt_ms = ("this", "is", "-a", "test");
        $opt_ver = undef;
        $Dpkg::opt_ver = "foobar";


To search for the filename stored in $testname which may or may not
already have a .asm extension and may be located in the directories
specified in $MODEL_ROOT or /usr/lib or /usr/local/lib:

        $asm_path = &Util::FindFile($testname, ".asm", 
                                    $MODEL_ROOT, 
                                    "/usr/lib:/usr/local/lib")

=head1 SEE ALSO

Getopt::Long, Getopt::Std

=cut


########################################################################
# RCS LOG
# 
# $Log: Util.pm,v $
# Revision 1.20  1997/09/04 22:38:41  chrisj
# Fixed bug in find_file where file w/ extension wasn't being checked first.
# Removed extra leading '/' from find_file when full path already given
#
# Revision 1.19  1997/09/03 22:33:39  chrisj
# Bugfix: &tmpfile shouldn't define $ENV{TMP} and $ENV{TEMP}
#
# Revision 1.18  1997/07/29 16:38:39  chrisj
# Added documentation for $Util::disable_env_vars and '&'-style switches.
#
# Revision 1.17  1997/07/08 02:49:21  chrisj
# Added error check for missing arguments to params which require an arg.
# Added ability to import routines from Util.pm into calling package.
# Added version variable.
#
# Revision 1.16  1997/04/10 21:05:36  chrisj
# Fixed strange warning caused by eval();
#
# Revision 1.15  1997/04/10 20:17:20  chrisj
# Fixed warnings when $TMP or $TEMP environment vars not defined.
#
# Revision 1.14  1997/04/08 21:28:02  chrisj
# Added &tmpfile() routine to produce valid path for temporary files.
#
# Revision 1.13  1997/04/01 23:58:34  chrisj
# Made special error and warning routines to allow caller to access messages.
#
# Revision 1.12  1997/03/28 01:46:38  chrisj
# Allow -opts-with-dashes now.
#
# Revision 1.11  1997/03/25 06:23:38  chrisj
# Now does "use strict"
# Massive overhaul to parse_opts()
#   a.  Terminator for arg list can now be -{opt}- instead of --
#   b.  Use my() variables instead of package vars
#   c.  Allow user to set Util::disable_env_vars before calling
#   d.  Allow switches with embedded '-' characters
#
# Revision 1.10  1997/02/11 22:01:35  chrisj
# Fixed warning when passing undefined ENV vars to find_file for search paths.
#
# Revision 1.9  1997/02/07 19:17:51  chrisj
# Fixed explicit package problem (again).
#
# Revision 1.8  1997/01/24 05:42:10  chrisj
# Updated to pass perl-qc.
#
#
########################################################################
