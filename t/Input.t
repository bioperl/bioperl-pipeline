#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 17;
    }
    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor;
    use Bio::Pipeline::SQL::InputAdaptor;
    use Bio::Pipeline::Input;
    use Bio::PrimarySeqI;
    ok(1);
    my $biopipe_test = BiopipeTestDB->new();

    $biopipe_test->do_sql_file("t/data/init.sql");

    my $dba = $biopipe_test->get_DBAdaptor();

    require Bio::Pipeline::SQL::InputAdaptor;
    my $ia = Bio::Pipeline::SQL::InputAdaptor->new($dba);
    ok defined $ia->isa("Bio::Pipeline::SQL::InputAdaptor");    

   # get an input
   my $input = $ia->fetch_fixed_input_by_dbID("1");

   ok $input->isa("Bio::Pipeline::Input"); 

   $name = $input->name;
   $jobid = $input->job_id;  
   ok $name, 'test1';
   ok $jobid, '1';

   $io = $input->input_handler;
   
   ok defined $io;
 
   
  my @datahandlers =  sort {$a->rank <=> $b->rank}$io->datahandlers;

  my $num = scalar(@datahandlers);
  ok $num, "2";

  my $datahandler1 = $datahandlers[0];
  my $datahandler2 = $datahandlers[1];

  my $dbID = $datahandler1->dbID;
  my $method = $datahandler1->method;
  my $argument = $datahandler1->argument;
  my $rank = $datahandler1->rank;
  
  ok $dbID, "1";
  ok $method, "new";
  ok $argument->[0]->tag, "-file";
  ok $argument->[0]->rank, "1";

  $dbID = $datahandler2->dbID;
  $method = $datahandler2->method;

  ok $dbID, "2";
  ok $method, "next_seq";
 
  my $obj = $input->fetch; 
  
  ok defined $obj;

  ok $obj->isa(Bio::PrimarySeqI);
  
  my $dispid = $obj->display_name;
  my $subseq = $obj->subseq(10,15);
  
  ok $dispid, "test1";
  ok $subseq, "CCCCCC";

