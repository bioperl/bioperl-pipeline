#!/usr/local/bin/perl


use strict;
use Bio::SeqIO;
use Bio::Seq;
use Bio::Pipeline::Runnable::Genewise;
use Bio::Pipeline::Analysis;
use Bio::Root::IO;

BEGIN {
     eval { require Test; };
     if( $@ ) {
        use lib 't';
     }
     use Test;
     use vars qw($NTESTS);
     $NTESTS = 15;
     plan tests => $NTESTS;
 }
  END {
     for ( $Test::ntest..$NTESTS ) {
          skip("Genewise program not found. Skipping.\n",1);
     }
  }
ok(1);
  unless (Bio::Root::IO->exists_exe('genewise')){
      warn "Genewise program not found. Skipping tests $Test::ntest to $NTESTS.\n";
      exit(0);
  }

 my $inputfilename = Bio::Root::IO->catfile("t","data","new_pep.fa");
 my $seqstream1 = Bio::SeqIO->new(-file => $inputfilename, -format => 'Fasta');
 my $seq1 = Bio::Seq->new();
 $seq1 = $seqstream1->next_seq();

 $inputfilename = Bio::Root::IO->catfile("t","data","new_dna.fa");
 my $seqstream2 = Bio::SeqIO->new(-file => $inputfilename, -fmt => 'Fasta');
 my $seq2 = Bio::Seq->new();
 $seq2 = $seqstream2->next_seq();
  
 my $analysis = Bio::Pipeline::Analysis->new();
 my $genewise = Bio::Pipeline::Runnable::Genewise->new();

 $genewise->query_pep($seq1);
 $genewise->target_dna($seq2);
  
  $genewise->analysis($analysis);
  eval{
     $genewise->run();
  };
  $@ && exit(0);
  my @genes = $genewise->output();
  ok($genes[0]->isa("Bio::SeqFeatureI"));#ok2
  my @transcripts = $genes[0]->transcripts;
  ok($transcripts[0]->isa("Bio::SeqFeature::Gene::TranscriptI"));#ok3
  my $no = scalar(@genes);
  my @feat = $transcripts[0]->exons;
  ok($feat[0]->isa("Bio::SeqFeature::Gene::ExonI"));#ok4
  my $seqname = $feat[0]->seq_id;
  my $start = $feat[0]->start;
  ok($start, 865);#ok5
  my $end = $feat[0]->end;
  ok($end, 897);#ok6
  my $strand = $feat[0]->strand;
  ok($strand, 1);#ok7


  my ($featpair) = $feat[0]->each_tag_value("supporting_feature");
  ok($featpair->feature1->start,865);
  ok($featpair->feature1->end,897);
  ok($featpair->feature1->strand,1);
  ok($featpair->feature1->score,17.01);
  ok($featpair->feature2->start,120);
  ok($featpair->feature2->end,130);
  ok($featpair->feature2->strand,1);
  ok($featpair->feature2->score,17.01);

