#!/usr/local/bin/perl

# Script for operating the analysis pipeline
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
#
# rewritten for bioperl-pipeline <shawnh@fugu-sg.org> and <juguang@fugu-sg.org>
#
#
# You may distribute this code under the same terms as perl itself


use strict;
use Getopt::Long;
use Bio::Pipeline::Manager;

# defaults: command line options override pipeConf variables,

use Bio::Pipeline::PipeConf qw (DBHOST 
                                DBNAME
                                DBUSER
                                DBPASS
                                NFSTMP_DIR
                                QUEUE
                                BATCHSIZE
                                USENODES
                                FETCH_JOB_SIZE
                                JOBNAME
                                RETRY
                                SLEEP
                                WAIT_FOR_ALL_PERCENT
                                TIMEOUT
                                
			                    );

$| = 1; #flush all print statements
my $flush        = 0;       #flush is used to check whether to flush all locks on pipeline and disregard  any that exist.
                            #should only be used for debugging.

my $local        = 0;       # Run failed jobs locally
my $resume       = 0;       # Flag to indicate whether resuming or doing a fresh run. 
                            # Used to check whether to do a CREATE_INPUT
my $INPUT_LIMIT = undef;
my $HELP = undef;
my $NUMBER=undef;
my $verbose = 0;

my $USAGE =<<END;
************************************
*PipelineManager.pl
************************************
This is the central script used to run the pipeline.

Usage: PipelineManager.pl 

Options:
Default values are read from PipeConf.pm

     -dbhost The database host name (localhost)
     -dbname The pipeline database name
     -dbpass The password to mysql database
     -flush  flush all locks on pipeline and remove any that exists. 
             Should only be used for debugging or development.
     -batchsize The number ofjobs to be batched to one node
     -local     Whether to run jobs in local mode 
                (on the node where this script is run)
     -number    Number of jobs to run (for testing)
     -queue     Specify the queue on which to submit jobs
     -verbose   Whether to show warning during test and setup
     -help      Display this help

END

GetOptions(
    'dbhost=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'flush'       => \$flush,
    'batchsize=i' => \$BATCHSIZE,
    'local'       => \$local,
    'resume'      => \$resume,
    'queue=s'     => \$QUEUE,
    'usenodes=s'  => \$USENODES,
    'retry=i'     => \$RETRY,
    'wait_for_all_percent=i'=>\$WAIT_FOR_ALL_PERCENT,
    'timeout=s'   => \$TIMEOUT,
    'verbose'     => \$verbose,
    'number=s'    => \$NUMBER,
    'help'        => \$HELP
)
or die $USAGE;

$HELP && die($USAGE);
$QUEUE = length($QUEUE) > 0 ? $QUEUE:undef;


# The code above is the same as PipelineManager.pl
# The lines below uses newly created Bio::Pipeline::Manager, 
# to replace the old scripts.


my $manager = Bio::Pipeline::Manager->new(
    -host       => $DBHOST,
    -dbname     => $DBNAME,
    -user       => $DBUSER,
    -pass       => $DBPASS,
    -flush      => $flush,
    -batchsize  => $BATCHSIZE,
    -local      => $local,
    -resume     => $resume,
    -queue      => $QUEUE,
    -usenodes   => $USENODES,
    -retry      => $RETRY,
    -timeout    => $TIMEOUT,
    -verbose    => $verbose,
    -number     => $NUMBER,
    -wait_for_all_percent   => $WAIT_FOR_ALL_PERCENT,

    -nfstmp_dir => $NFSTMP_DIR,
    -fetch_job_size => $FETCH_JOB_SIZE,
    -sleep      => $SLEEP,
    -batchsize  => $BATCHSIZE,
    -input_limit    => $INPUT_LIMIT
);

$manager->check_lock;
$manager->create_lock;
$manager->test_analysis if 1;
$manager->run;

