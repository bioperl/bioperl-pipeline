# BioPerl Bio::Pipeline::PipeConf
#
# configuration information

=head1 DESCRIPTION
PipeConf is a copy of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%PipeConf> hash is asked to be set.

The variables can also be references to arrays or hashes.

All the variables are in capitals, so that they resemble environment
variables.
=cut


package Bio::Pipeline::PipeConf;
use strict;
use vars qw (%PipeConf);



%PipeConf = ( 

    # working directory for err/outfiles
    NFSTMP_DIR => '/home/jerm/tmp/',

    # database specific variables
    DBI_DRIVER => 'mysql',
    DBHOST     => 'localhost',
    DBNAME     => 'bioperl_pipeline',
    DBUSER     => 'root',
    DBPASS     => '',	     

    # default directory for data files and binary files
    BINDIR     => '',
    DATADIR    => '',

    # Batch Management system module
    BATCH_MOD   =>  'LSF',
    # farm queue
    QUEUE      => '', 
    # farm nodes to use, default all
    USENODES    =>'',
    # jobname
    JOBNAME    =>'',
    # true->update InputIdAnalysis via Job
    AUTOUPDATE => 1,    

    # no of jobs to send to Batch Management system at one go
    BATCHSIZE  => 1,        
    BSUB_OPT   => '-C0',

    # number of times to retry a failed job
    RETRY       => '5',
    # path to runner.pl, needed by Job.pm
    RUNNER     => '',   
    #sleep time in Rulemanager
    SLEEP      => 3600,
    );

sub import {
    my ($callpack) = caller(0); # Name of the calling package
    my $pack = shift; # Need to move package off @_

    # Get list of variables supplied, or else
    # all of GeneConf:
    my @vars = @_ ? @_ : keys( %PipeConf );
    return unless @vars;

    # Predeclare global variables in calling package
    eval "package $callpack; use vars qw("
         . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $PipeConf{ $_ } ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$PipeConf{ $_ };
	} else {
	    die "Error: PipeConf: $_ not known\n";
	}
    }
}

1;
