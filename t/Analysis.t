#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 6;
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor; 
    use Bio::Pipeline::IOHandler;
    use Bio::Pipeline::DataHandler;
    use Bio::Pipeline::Analysis;




    my $biopipe_test = BiopipeTestDB->new();
    
    ok $biopipe_test; 

    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba->isa("Bio::Pipeline::SQL::DBAdaptor");
    my $analysisAdaptor = $dba->get_AnalysisAdaptor;
    ok $analysisAdaptor->isa("Bio::Pipeline::SQL::AnalysisAdaptor");

    my $datahandler_obj = Bio::Pipeline::DataHandler->new(-dbid => 1,
                                                          -method => "fake_method",
                                                          -argument=>[],
                                                          -rank => 1);
    push @datahandler, $datahandler_obj;

    my $iohandler_obj = Bio::Pipeline::IOHandler->new_ioh_db(-dbid=>1,
                                                             -type=>"OUTPUT",
                                                             -dbadaptor_dbname=>"test_db",
                                                             -dbadaptor_driver=>"mysql",
                                                             -dbadaptor_host=>"mysql",
                                                             -dbadaptor_user=>"root",
                                                             -dbadaptor_pass=>"",
                                                             -dbadaptor_module=>"Bio::DB::SQL::DBAdaptor",
                                                             -datahandlers => \@datahandler);

    my $ioid = $dba->get_IOHandlerAdaptor->store($iohandler_obj);

    my @ioh;
    push @ioh, $iohandler_obj;
    my $analysis = Bio::Pipeline::Analysis->new(
		   -logic_name      => 'SWIRBlast',
		   -db              => 'swissprot',
		   -db_version      => 1,
		   -db_file         => '/data/swissprot',
		   -program         => 'blastp',
		   -program_version => 1,
		   -program_file    => '/usr/local/bin/blastp',
		   -gff_source      => 'similarity',
		   -gff_feature     => 'swiss',
		   -runnable        => 'Bio::Pipeline::Runnable::Blast',
		   -runnable_version  => 1,
		   -parameters      => '',
       -iohandler  =>\@ioh
	      	   );

    my $id = $analysisAdaptor->store($analysis);
    ok $id,1;

    my @analysis = $analysisAdaptor->fetch_all();


    my $logicName = $analysis[0]->logic_name;
    my $runnable = $analysis[0]->runnable; 
   
    ok $logicName, 'SWIRBlast';
    ok $runnable, 'Bio::Pipeline::Runnable::Blast';
 
   



