#!/usr/local/bin/perl


#add test dir to lib search path
BEGIN {
    use lib 't';
    use Test;
    plan tests => 12;
}

END {
     foreach( $Test::ntest..NUMTESTS) {
      skip('Blast or env variables not installed correctly',1);
     }
    unlink "t/data/blast_dir/blast.fa.1";
    unlink "t/data/blast_dir/blast.fa.2";
    unlink "t/data/blast_dir/blast.fa.3";
    unlink "t/data/blast_dir/blast.fa.4";
    unlink "t/data/blast_dir/blast.fa.5";
    unlink "t/data/blast_result/blast.fa.1.bls";
    unlink "t/data/blast_result/blast.fa.2.bls";
    unlink "t/data/blast_result/blast.fa.3.bls";
    unlink "t/data/blast_result/blast.fa.4.bls";
    unlink "t/data/blast_result/blast.fa.5.bls";
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

open (STDERR, ">/dev/null");
$biopipe_test->do_xml_file("xml/templates/blast_file_pipeline.xml"),0;

$biopipe_test->run_pipeline(), 0;

ok -e "t/data/blast_dir/blast.fa.1";
ok -e "t/data/blast_dir/blast.fa.2";
ok -e "t/data/blast_dir/blast.fa.3";
ok -e "t/data/blast_dir/blast.fa.4";
ok -e "t/data/blast_dir/blast.fa.5";
ok -e "t/data/blast_result/blast.fa.1.bls";
ok -e "t/data/blast_result/blast.fa.2.bls";
ok -e "t/data/blast_result/blast.fa.3.bls";
ok -e "t/data/blast_result/blast.fa.4.bls";
ok -e "t/data/blast_result/blast.fa.5.bls";







