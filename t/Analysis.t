#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 6;
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor; 



    my $biopipe_test = BiopipeTestDB->new();
    
    ok $biopipe_test; 

    $dbh = $biopipe_test->db_handle();
    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba;
    my $analysisAdaptor = $dba->get_AnalysisAdaptor;
    ok $analysisAdaptor;
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
	      	   );

    my $id = $analysisAdaptor->store($analysis);
    ok $id,1;

    my $logicName = $analysis->logic_name;
    my $runnable = $analysis->runnable; 
   
    ok $logicName, 'SWIRBlast';
    ok $runnable, 'Bio::Pipeline::Runnable::Blast';
 
   



