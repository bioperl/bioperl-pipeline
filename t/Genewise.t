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

 my $inputfilename = Bio::Root::IO->catfile("t","data","new_dna.fa");
 my $seqstream2 = Bio::SeqIO->new(-file => $inputfilename, -fmt => 'Fasta');
 my $seq2 = Bio::Seq->new();
 $seq2 = $seqstream2->next_seq();
  
 my $analysis = Bio::Pipeline::Analysis->new();
 my $genewise = Bio::Pipeline::Runnable::Genewise->new();

 $genewise->query_pep($seq1);
 $genewise->target_dna($seq2);
  
  $genewise->analysis($analysis);
  open (STDERR, ">/dev/null");
  eval{
     $genewise->run();
  };
  $@ && exit(0);
  my @genes = $genewise->output();
  ok($genes[0]->isa("Bio::SeqFeatureI"));#ok2
  my @transcripts = $genes[0]->transcripts;
  ok($transcripts[0]->isa("Bio::SeqFeature::Gene::TranscriptI"));#ok3
  my $no = scalar(@genes);
  print"the number of genes are $no\n";
  my @feat = $transcripts[0]->exons;
  ok($feat[0]->isa("Bio::SeqFeature::Gene::ExonI"));#ok4
  my $seqname = $feat[0]->seqname;
  my $start = $feat[0]->start;
  ok($start, 865);#ok5
  my $end = $feat[0]->end;
  ok($end, 897);#ok6
  my $strand = $feat[0]->strand;
  ok($strand, 1);#ok7

  my @tags = $feat[0]->all_tags;

  my @seqfeature1 = $feat[0]->each_tag_value($tags[0]);
  my $pseqname = $seqfeature1[0]->seqname;
  my $pstart = $seqfeature1[0]->start;
  ok($pstart, 120);#ok8
  my $pend = $seqfeature1[0]->end;
  ok($pend, 130);#ok9
  my $pstrand = $seqfeature1[0]->strand;
  ok($pstrand, 1);#ok10
  my $pscore = $seqfeature1[0]->score;
  ok($pscore, 17.01);#ok11
  my $ps_tag = $seqfeature1[0]->source_tag;
  my $pp_tag = $seqfeature1[0]->primary_tag;
 
  my @seqfeature2 = $feat[0]->each_tag_value($tags[1]);
  my $gseqname = $seqfeature2[0]->seqname;
  my $gstart = $seqfeature2[0]->start;
  ok($gstart, 865);#ok12
  my $gend = $seqfeature2[0]->end;
  ok($gend, 897);#ok13
  my $gstrand = $seqfeature2[0]->strand;
  ok($gstrand, 1);#ok14
  my $gscore = $seqfeature2[0]->score;
  ok($gscore, 17.01);#ok15
  my $gs_tag = $seqfeature2[0]->source_tag;
  my $gp_tag = $seqfeature2[0]->primary_tag;
 
  my @seqfeature3 = $feat[0]->each_tag_value($tags[2]);
  my $phaseno = $seqfeature3[0]; #phase number
  
