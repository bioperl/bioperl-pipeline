#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 10;
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor; 



    my $biopipe_test = BiopipeTestDB->new();
    
    ok $biopipe_test; 
    print "Test Database creation success\n";

    #$biopipe_test->do_sql_file("sql/initdata.sql");
     
    
    $dbh = $biopipe_test->db_handle();
    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba;

    print "Creating a job  object \n";
 
    my $jobAdaptor = $dba->get_JobAdaptor;
    ok $jobAdaptor;

    my $job = $jobAdaptor->fetch_by_dbID('1');
    ok $job;

    my $analysis = $job->analysis;
    my $adaptor = $job->adaptor;
    
    ok $analysis;
    ok $adaptor;
    
    my @inputs = $job->inputs;
    my $numinputs = scalar(@inputs);

    ok $numinputs, 1;

    my $input = @inputs[0];

    ok $input;
    
    my $jobid = $input->job_id;
    ok $jobid, 1;

    print "Checking Job  details - Success \n";
  
    print "Running the job..\n"; 
    $status = $job->status;
    ok $status, 'NEW';

    eval {
       $job->run;
    };
    $err = $@;

    ok $err, '';

    my @newjobs = create_new_job($job);
    my $numnewjobs = scalar(@newjobs);
    ok $numnewjobs, 1;

    my $newjob = @newjobs[0];

sub create_new_job{
    my ($job) = @_;
    my @new_jobs;
    my $ruleAdaptor = $dba->get_RuleAdaptor;
    my @rules = $ruleAdaptor->fetch_all;
    foreach my $rule (@rules){
        if ($rule->condition == $job->analysis->dbID){
            my $new_job = $job->create_next_job($rule->goalAnalysis);
            push (@new_jobs,$new_job);
        }
    }
    return @new_jobs;
}

