#!/usr/local/bin/perl

#add test dir to lib search path
BEGIN {
    use lib 't';
    use Test;
    $NTESTS = 4;
    plan tests => $NTESTS;
}
use strict;
use vars qw($NTESTS);
use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::BatchSubmission;
use Bio::Root::IO;

    unless (Bio::Root::IO->exists_exe('bsub') || Bio::Root::IO->exists_exe('qsub')){
	warn "Job Scheduler not installed. Skipping test $Test::ntest to $NTESTS\n";
	exit(0);
    }
    END {
	for ( $Test::ntest..$NTESTS ) {
                skip("Job Scheduler not found. Skipping.\n",1);
          }
    }
    my $biopipe_test = BiopipeTestDB->new();

    ok $biopipe_test;

    $biopipe_test->do_sql_file("t/data/init.sql");


    my $dba = $biopipe_test->get_DBAdaptor();
    my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$dba);
    $batchsubmitter->runner_path("scripts/runner.pl");

    ok $batchsubmitter;

    my $jobAdaptor  = $dba->get_JobAdaptor;
    my @jobs = $jobAdaptor->fetch_jobs; 

    my $job = $jobs[0];
    ok $job;

    $batchsubmitter->add_job($job);
    eval {
       $batchsubmitter->submit_batch;
    };
    if ($@){
       warn($@);

    }
    $job->update;    
    my $jobstatus = $job->status;
    ok $jobstatus, 'SUBMITTED';

