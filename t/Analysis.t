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

    print "Creating a analysis object \n";
 
    my $analysisAdaptor = $dba->get_AnalysisAdaptor;
    ok $analysisAdaptor;

    my $analysis = $analysisAdaptor->fetch_by_dbID('3');
    ok $analysis;

    my $logicName = $analysis->logic_name;
    my $runnable = $analysis->runnable; 
   
    ok $logicName, 'test';
    ok $runnable, 'Bio::Pipeline::Runnable::TestRunnable';
 
    print "Checking analysis details - Success\n";
   



