
use strict;

BEGIN {
    use lib 't';
    use Test;
    plan tests => 9;
}

END {
    
}

use Bio::SearchIO;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::RawContig;

use Bio::Pipeline::Utils::Converter;

my $searchio = new Bio::SearchIO(
    -format => 'blast',
    -file => 't/data/out.blast'
);

my @hsps = ();
while(my $result = $searchio->next_result){
    while(my $hit = $result->next_hit){
        while(my $hsp = $hit->next_hsp){
            push @hsps, $hsp;
        }
    }
}

my $ens_analysis = new Bio::EnsEMBL::Analysis(
    -dbID => 1
);
my $ens_contig = new Bio::EnsEMBL::RawContig(
    -dbID => 1
);

my $converter = new Bio::Pipeline::Utils::Converter(
    -in => 'Bio::Search::HSP::GenericHSP',
    -out => 'Bio::EnsEMBL::BaseAlignFeature',
    -analysis => $ens_analysis,
    -contig => $ens_contig,
    -program => 'blastx'
);

my @ens_alignFeatures = @{$converter->convert(\@hsps)};

$_ = shift @ens_alignFeatures;

ok $_->start, 26;
ok $_->end, 319;
ok $_->strand, 1;
ok $_->hstart, 1143;
ok $_->hend, 1242;
ok $_->hstrand, 0;
ok $_->p_value, '9e-22';
ok $_->score, 337;
ok $_->percent_id, 54;


#    print($_->cigar_string . "\n") foreach(@ens_alignFeatures);

