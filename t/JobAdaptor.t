#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 13;
    }

    END {
        unlink("t/data/testout.fa");
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor; 
    use Bio::Pipeline::Input;
    use Bio::Pipeline::Job;
    use Bio::SeqIO;

    my $biopipe_test = BiopipeTestDB->new();
    
    ok $biopipe_test; 

    $biopipe_test->do_sql_file("t/data/init.sql");
     
    
    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba;

    my $jobAdaptor = $dba->get_JobAdaptor;
    ok $jobAdaptor;

    my $anal = new Bio::Pipeline::Analysis(
        -id              => 2,
        -logic_name      => 'testanalysis',
        -runnable        => "Bio::Pipeline::TestRunnable",
        );

    my @input;
    for(my $i = 0; $i < 5; $i++){
        push @input, Bio::Pipeline::Input->new(-name=>"input_$i",-input_handler=>1);
    } 
    my $job = Bio::Pipeline::Job->new(-analysis=>$anal,-inputs=>\@input);

    $jobAdaptor->store($job);

    $job->set_status("FAILED");
    $job->set_stage("WRITING");

    ($job) = $jobAdaptor->fetch_jobs(-status=>['FAILED'],-stage=>['WRITING'],-analysis_id=>2);
    ok $job->dbID, 3;  
    ok scalar($job->inputs), 5;

    ($job) = $jobAdaptor->fetch_jobs(-dbID=>3);
    ok $job->dbID, 3;  
    ok scalar($job->inputs), 5;
    
    my ($job_id) = $jobAdaptor->list_job_ids(-status=>['FAILED'],-stage=>['WRITING'],-analysis_id=>2);

    ok $job_id, 3;

    $jobAdaptor->update_completed_job($job);

    ($job_id) = $jobAdaptor->list_completed_job_ids(-analysis_id=>2);

     ok $job_id,3;

    ($job_id) = $jobAdaptor->list_completed_job_ids(-dbID=>3);

     ok $job_id,3;

     my $job_count = $jobAdaptor->get_job_count(-status=>['FAILED']);

     ok $job_count, 1;
     
     $job_count = $jobAdaptor->get_job_count();

     ok $job_count, 3;

     $job->retry_count(3);

     $job->update;

     $job_count = $jobAdaptor->get_job_count(-retry_count=>3);

     ok $job_count, 3;








