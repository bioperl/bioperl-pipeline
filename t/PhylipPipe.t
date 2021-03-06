#!/usr/local/bin/perl


#add test dir to lib search path
BEGIN {
    use lib 't';
    use Test;
    $NUMTESTS=8;
    plan tests=> 8;
}

END {
     foreach( $Test::ntest..$NUMTESTS) {
      skip('Blast or env variables not installed correctly',1);
     }
    unlink <t/data/phylip_dir/*>;
    unlink <t/data/phylip_result/*>;
    rmdir "t/data/phylip_dir";
    rmdir "t/data/phylip_result";
    
}

use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Tools::Run::StandAloneBlast;
use Bio::SeqIO;
use Bio::Tools::Run::Alignment::Clustalw;
use Bio::Tools::Run::Phylo::Phylip::ProtDist;

my  $factory = Bio::Tools::Run::Alignment::Clustalw->new();
unless($factory->executable){
        warn("Clustalw program not found. Skipping tests $Test::ntest to $NTESTS.\n");
        exit 0;
}

#test for one program is enuff.
$factory = Bio::Tools::Run::Phylo::Phylip::ProtDist->new();
unless($factory->executable){
            warn("Phylip Package not found. Skipping tests $Test::ntest to $NTESTS.\n");
            exit 0;
}


my $biopipe_test = BiopipeTestDB->new();
ok $biopipe_test;

eval {
   require('XML/Parser.pm');
};
if ($@) {
   warn(" XML::Parser not installed, skipping test. Pls install Bundle::BioPerl from CPAN");
   skip('XML::Parser not installed',1);
   exit;
}

$biopipe_test->run_pipeline("xml/templates/phylip_tree_pipeline.xml"), 0;

ok -e "t/data/phylip_dir/cysprot.fa.1";
ok -e "t/data/phylip_result/cysprot.fa.1.cls";
ok -e "t/data/phylip_result/cysprot.fa.1.con";
ok -e "t/data/phylip_result/cysprot.fa.1.con.ps";
ok -e "t/data/phylip_result/cysprot.fa.1.nb";
ok -e "t/data/phylip_result/cysprot.fa.1.pd";
ok -e "t/data/phylip_result/cysprot.fa.1.sb";



