#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    use Bio::Pipeline::PipeConf;
    plan tests => 13;
    }

    END {
        unlink("t/data/testout.fa");
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor; 
    use Bio::SeqIO;

    my $biopipe_test = BiopipeTestDB->new();
    
    ok $biopipe_test; 

    $biopipe_test->do_sql_file("t/data/init.sql");
     
    
    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba;

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

    ok $inputs[0]->isa("Bio::Pipeline::Input");
    
    my $jobid = $inputs[0]->job_id;
    ok $jobid, 1;

    $status = $job->status;
    ok $status, 'NEW';

    eval {
       $job->run_local;
    };
    $err = $@;

    ok $err, '';

    my $seqio = Bio::SeqIO->new(-file=>"t/data/testin.fa",-format=>'Fasta');
    my $seq = $seqio->next_seq;
    $seqio = Bio::SeqIO->new(-file=>"t/data/testout.fa",-format=>'Fasta');
    my $seq2 = $seqio->next_seq;

    #check test runnable completed correctly
    ok ($seq->revcom->seq eq $seq2->seq);

    my @newjobs = create_new_job($job);
    my $numnewjobs = scalar(@newjobs);
    ok $numnewjobs, 1;

    my $newjob = $newjobs[0];

sub create_new_job{
    my ($job) = @_;
    my @new_jobs;
    my $ruleAdaptor = $dba->get_RuleAdaptor;
    my @rules = $ruleAdaptor->fetch_all;
    foreach my $rule (@rules){
        if ($rule->current->dbID == $job->analysis->dbID){
            my $new_job = $job->create_next_job($rule->next);
            push (@new_jobs,$new_job);
        }
    }
    return @new_jobs;
}

