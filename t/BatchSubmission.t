#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 10;
    }
    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor;
    use Bio::Pipeline::BatchSubmission;



    my $biopipe_test = BiopipeTestDB->new();

    ok $biopipe_test;
    print "Test Database creation success\n";

    $dbh = $biopipe_test->db_handle();

    my $dba = $biopipe_test->get_DBAdaptor();
    my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$dba);

    ok $batchsubmitter;

    my $jobAdaptor  = $dba->get_JobAdaptor;
    my @jobs = $jobAdaptor->fetch_all; 

    my $job = $jobs[0];
    ok $job;

    $batchsubmitter->add_job($job);
    eval {
       $batchsubmitter->submit_batch;
    };
    my $err = $@;
    if ($err){
        print "Error : $err\n";
    }
    
    my $jobstatus = $job->status;
    ok $jobstatus, 'SUBMITTED';

