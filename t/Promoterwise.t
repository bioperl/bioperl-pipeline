#!/usr/local/bin/perl


use strict;
use Bio::SeqIO;
use Bio::Seq;
use Bio::Pipeline::Runnable::Promoterwise;
use Bio::Pipeline::Analysis;
use Bio::Root::IO;

BEGIN {
     eval { require Test; };
     if( $@ ) {
        use lib 't';
     }
     use Test;
     use vars qw($NTESTS);
     $NTESTS = 9;
     plan tests => $NTESTS;
 }
  END {
     for ( $Test::ntest..$NTESTS ) {
          skip("Promoterwise program not found. Skipping.\n",1);
     }
  }
ok(1);#ok1

my $verbose=0;
my @params=('verbose'=>$verbose,'silent'=>1,'quiet'=>1);
my $factory=Bio::Tools::Run::Promoterwise->new(@params);
ok $factory->isa('Bio::Tools::Run::Promoterwise'); #ok2
unless ($factory->executable) {
  warn "Promoterwise program not found. Skipping tests $Test::ntest to $NTESTS.\n";
  exit(0);
}

my $inputfilename = Bio::Root::IO->catfile(qw(t data cdna.fa));
my $seqstream1 = Bio::SeqIO->new(-file => $inputfilename, -format => 'Fasta');
my $seq1 = Bio::Seq->new();
$seq1 = $seqstream1->next_seq();

$inputfilename = Bio::Root::IO->catfile(qw(t data genomic.fa));
my $seqstream2 = Bio::SeqIO->new(-file => $inputfilename, -fmt => 'Fasta');
my $seq2 = Bio::Seq->new();
$seq2 = $seqstream2->next_seq();
  
my $analysis = Bio::Pipeline::Analysis->new();
$analysis->analysis_parameters("-silent 1 -quiet 1");
my $promoterwise = Bio::Pipeline::Runnable::Promoterwise->new();

$promoterwise->subject_dna($seq1);
$promoterwise->target_dna($seq2);
  
$promoterwise->analysis($analysis);
$promoterwise->run();

my @promoters = $promoterwise->output();
ok($promoters[0]->isa("Bio::SeqFeatureI")); #ok3

my $first=$promoters[0]->feature1;
my $second=$promoters[0]->feature2;
my @sub=$first->sub_SeqFeature;
my @sub2=$second->sub_SeqFeature;

ok $sub[0]->start,4; #ok4
ok $sub2[0]->start,29; #ok5
ok $sub[0]->end,18; #ok6
ok $sub2[0]->end,43; #ok7
ok $sub[0]->seq->seq,'GTTGTGCTGGGGGGG'; #ok8
ok $sub[0]->score,1596.49; #ok9
