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

=head1

=cut


package Bio::Pipeline::PipeConf;
use strict;
use vars qw (%PipeConf);



%PipeConf = ( 

    # You will need to modify these variables

    # working directory for err/outfiles
    NFSTMP_DIR => '/tmp/',
    WORKDIR    => '/tmp/',

    # database specific variables
    
    DBI_DRIVER => 'mysql',
    DBHOST     => 'localhost',
    DBNAME     => 'yourdbhere',
    DBUSER     => 'root',
    DBPASS     => '',	     

    # Batch Management system module
    # Currently supports PBS and LSF
    BATCH_MOD   =>  'LSF',
    # farm queue
    QUEUE      => 'normal3', 
    # farm nodes to use, default all
    
    # no of jobs to send to Batch Management system at one go
    BATCHSIZE  => 3,        

    #bsub opt
    BSUB_OPT   => '-C0',

    # number of times to retry a failed job
    RETRY       => '1000',

    # path to runner.pl, use by the BatchSubmission objects
    # to look for runner.pl. If not supplied it looks in the default 
    # directory where PipelineManager lies
    RUNNER     => '',   

    #sleep time in PipelineManager before waking up and looking for jobs to run 
    SLEEP      => 100,

    ##############################################
    # NOT SUPPORTED CURRENTLY FOR FUTURE DEV
    # default directory for data files and binary files
    #BINDIR     => '',
    #DATADIR    => '',
    #USENODES    =>'',
    # jobname
    #JOBNAME    =>'',
    # true->update InputIdAnalysis via Job
    #AUTOUPDATE => 1,    
    #WAIT_FOR_ALL_PERCENT => 0,
    #TIMEOUT    => 100,
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
