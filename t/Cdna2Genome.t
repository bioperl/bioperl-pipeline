#!/usr/local/bin/perl


#add test dir to lib search path
BEGIN {
    use lib 't';
    use Test;
    $NTESTS = 5;
    plan tests => $NTESTS;
}

END {
     foreach( $Test::ntest..$NTESTS) {
      skip('Blast or env variables not installed correctly',1);
     }
    unlink <t/data/cdna2genome_results/*>;
    unlink <t/data/cdna2genome_results/blast_dir/*>;
    rmdir "t/data/cdna2genome_results/blast_dir/";
    rmdir "t/data/cdna2genome_results";
    
}

use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Tools::Run::Alignment::Sim4;
use Bio::SeqIO;

my  $factory = Bio::Tools::Run::Alignment::Sim4->new();

my $sim4_present = $factory->executable('sim4');
if( ! $sim4_present ) {
        skip('Sim4 not installed',1);
            exit;
} else {
        ok($sim4_present);
}

my $biopipe_test = BiopipeTestDB->new();
ok $biopipe_test;

open (STDERR, ">/dev/null");
eval {
   require('XML/Parser.pm');
};
if ($@) {
   warn(" XML::Parser not installed, skipping test"); 
   skip('XML::Parser not installed',1);
   exit;
}  
$biopipe_test->do_xml_file("xml/templates/cdna2genome_pipeline.xml"),0;

$biopipe_test->run_pipeline(), 0;

ok -e "t/data/cdna2genome_results/MUSSPSYN.gff";
ok -e "t/data/cdna2genome_results/cdna.fa.1";
ok -e "t/data/cdna2genome_results/blast_dir/cdna.fa.1.bls";


