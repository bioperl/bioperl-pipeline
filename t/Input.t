#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 10;
    }
    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor;
    use Bio::Pipeline::SQL::InputAdaptor;
    use Bio::Pipeline::Input;
    use Bio::PrimarySeqI;
    ok(1);
    my $biopipe_test = BiopipeTestDB->new();

    ok $biopipe_test; #"Test database not created";   
    print "Test Database creation success \n";

    $dbh = $biopipe_test->db_handle();
    my $dba = $biopipe_test->get_DBAdaptor();

    require Bio::Pipeline::SQL::InputAdaptor;
    my $ia = Bio::Pipeline::SQL::InputAdaptor->new
      ( $dba);
   ok defined $ia;    

   print "Pipeline Input adaptor creation success\n";

   # get an input
   my $input = $ia->fetch_by_dbID("1");

   ok defined $input; 
   print "Pipeline Input object fetch from db a succes\n";

   $name = $input->name;
   $jobid = $input->job_id;  
   ok $name, 'input1';
   ok $jobid, '1';
   
   print "Pipeline Input details verification success\n";

   $io = $input->input_handler;
   
   ok defined $io;
 
   
  ok $io->dbID, "1";
  ok $io->dbadaptor_dbname, "bioperl_db";
  ok $io->dbadaptor_driver, "mysql";
  ok $io->dbadaptor_host, "localhost";
  ok $io->dbadaptor_module, "SQL::DBAdaptor";
  ok $io->dbadaptor_user, "root";

  print "Pipeline Inputs IOHandler details verification success\n";
 
  my @datahandlers =  sort {$a->rank <=> $b->rank}$io->datahandlers;

  my $num = scalar(@datahandlers);
  ok $num, "2";

  my $datahandler1 = @datahandlers[0];
  my $datahandler2 = @datahandlers[1];

  my $dbID, $method, $argument, $rank;
  $dbID = $datahandler1->dbID;
  $method = $datahandler1->method;
  $argument = $datahandler1->argument;
  $rank = $datahandler1->rank;
  
  ok $dbID, "1";
  ok $method, "get_PrimarySeqAdaptor";
  ok $argument, "";
  ok $rank, "1";

  $dbID = $datahandler2->dbID;
  $method = $datahandler2->method;
  $argument = $datahandler2->argument;
  $rank = $datahandler2->rank;

  ok $dbID, "2";
  ok $method, "fetch_by_dbID";
  ok $argument, "1";
  ok $rank, "2";
 
  print "Pipeline Inputs Data handlers details verification success\n";

  my $obj = $input->fetch; 
  
  ok defined $obj;

  ok $obj->isa(Bio::PrimarySeqI);
  
  my $dispid = $obj->display_id;
  my $primaryid = $obj->primary_id;
  my $subseq = $obj->subseq(10,15);
  
  ok $dispid, "AF197897";
  ok $primaryid, "1";
  ok $subseq, "GGAGAA";

  print "Analysis Input Object details verification success\n";
