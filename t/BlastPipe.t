#!/usr/local/bin/perl


#add test dir to lib search path
BEGIN {
    use lib 't';
    use Test;
    $NTESTS = 12;
    plan tests => $NTESTS;
}

END {
     foreach( $Test::ntest..$NTESTS) {
      skip('Blast or env variables not installed correctly',1);
     }
    unlink <t/data/blast_dir/*>;
    unlink <t/data/blast_result/*>;
    rmdir "t/data/blast_dir";
    rmdir "t/data/blast_result";
    
}

use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Tools::Run::StandAloneBlast;
use Bio::SeqIO;

my  $factory = Bio::Tools::Run::StandAloneBlast->new();

my $blast_present = $factory->executable('blastall');
if( ! $blast_present ) {
        skip('Blast not installed',1);
            exit;
} else {
        ok($blast_present);
}

my $biopipe_test = BiopipeTestDB->new();
ok $biopipe_test;

eval {
   require('XML/Parser.pm');
};
if ($@) {
   warn(" XML::Parser not installed, skipping test"); 
   skip('XML::Parser not installed',1);
   exit;
}  

$biopipe_test->run_pipeline("xml/templates/blast_file_pipeline.xml"), 0;

ok -e "t/data/blast_dir/input.fa.1";
ok -e "t/data/blast_dir/input.fa.2";
ok -e "t/data/blast_dir/input.fa.3";
ok -e "t/data/blast_dir/input.fa.4";
ok -e "t/data/blast_dir/input.fa.5";
ok -e "t/data/blast_result/input.fa.1.bls";
ok -e "t/data/blast_result/input.fa.2.bls";
ok -e "t/data/blast_result/input.fa.3.bls";
ok -e "t/data/blast_result/input.fa.4.bls";
ok -e "t/data/blast_result/input.fa.5.bls";
