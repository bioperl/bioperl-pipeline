# BioPerl Bio::Pipeline::PipeConf
#
# configuration information

=head1 NAME

Bio::Pipeline::PipeConf

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

    # You will need to modify these variables

    # working directory for err/outfiles
    NFSTMP_DIR => '/data0/tmp/',

    # database specific variables
    
    DBI_DRIVER => 'mysql',
    DBHOST     => 'mysql',
    DBNAME     => 'annotate_pipeline',
    DBUSER     => 'root',
    DBPASS     => '',	     

    # Batch Management system module
    # Currently supports PBS and LSF
    # ignored if run in local mode
    BATCH_MOD   =>  'LSF',

    # farm queue
    QUEUE      => 'normal3', 
    
    # no of jobs to send to Batch Management system at one go
    BATCHSIZE  => 3,        

    #bsub opt
    BATCH_PARAM => '-C0',

    # no of jobs to fetch at a time and submit
    MAX_INCOMPLETE_JOBS_BATCHSIZE => 1000,
 
    # no of completed jobs to fetch at a time and create next jobs 
    MAX_CREATE_NEXT_JOBS_BATCHSIZE => 5,


    # number of times to retry a failed job
    RETRY       => '1000',

    # path to runner.pl, use by the BatchSubmission objects
    # to look for runner.pl. If not supplied it looks in the default 
    # directory where PipelineManager lies
    RUNNER     => '',   

    #sleep time in PipelineManager before waking up and looking for jobs to run 
    SLEEP      => 3,

    FETCH_JOB_SIZE => 100,

    ##############################################
    # PARAMS FROM HERE ON NOT SUPPORTED CURRENTLY FOR FUTURE DEV
    # default directory for data files and binary files
    WORKDIR    => '',
    BINDIR     => '',
    DATADIR    => '',
    USENODES    =>'',
    # jobname
    JOBNAME    =>'',
    # true->update InputIdAnalysis via Job
    AUTOUPDATE => 1,    
    WAIT_FOR_ALL_PERCENT => 0,
    TIMEOUT    => 100,
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
