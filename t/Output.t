#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 10;
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor;
    use Bio::EnsEMBL::SeqFeature;


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
    
    my $io = $analysis->output_handler;
     ok defined $io;


  ok $io->dbID, "2";
  ok $io->dbadaptor_dbname, "bioperl_db";
  ok $io->dbadaptor_driver, "mysql";
  ok $io->dbadaptor_host, "localhost";
  ok $io->dbadaptor_module, "SQL::DBAdaptor";
  ok $io->dbadaptor_user, "root";

  print "Pipeline Output's IOHandler details verification success\n";

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

  ok $dbID, "3";
  ok $method, "get_SeqFeatureAdaptor";
  ok $argument, "";
  ok $rank, "1";

  $dbID = $datahandler2->dbID;
  $method = $datahandler2->method;
  $argument = $datahandler2->argument;
  $rank = $datahandler2->rank;

  ok $dbID, "4";
  ok $method, "store";
  ok $argument, "OUTPUT";
  ok $rank, "2";

  print "Pipeline Outputs Data handlers details verification success\n";

   my @feats;
        my $feat = new Bio::EnsEMBL::SeqFeature(-seqname=>'Scaffold_267_153',
                                                -start => 10,
                                                -analysis=>$analysis,
                                                -end   => 20,
                                                -score =>100,
                                                -source_tag=>"source_tag",
                                                -primary_tag=>"pri_tag",
                                                -strand =>-1);
       push @feats, $feat;

  eval {
    $io->write_output(@feats); 
  };
  my $err = $@;
  ok $err, "";

  print "Writint Output - Success\n";
