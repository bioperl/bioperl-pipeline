#!/usr/local/bin/perl

use strict;
use Bio::SeqIO;
use Bio::Seq;
use Bio::Pipeline::Runnable::Genscan;
use Bio::Pipeline::Analysis;
use Bio::Root::IO;
  
  BEGIN {
      eval { require Test; };
      if( $@ ) {
          use lib 't';
      }
      use Test;
      use vars qw($NTESTS);
      $NTESTS = 12;
      plan tests => $NTESTS;
  }
  
  
  
  
  
  
   # create and fill Bio::Seq object
   my $seqfile = Bio::Root::IO->catfile("data","Genscan.FastA");
   my $seq1 = Bio::Seq->new();
   my $seqstream = Bio::SeqIO->new(-file => $seqfile, -fmt => 'Fasta');
   $seq1 = $seqstream->next_seq();

   # create a analysis object (with just enough arguments for now that the runnable needs)
   my $parameters = '-MATRIX data/HumanIso.smat';
   my $analysis = Bio::Pipeline::Analysis->new(-parameters => $parameters);
   
   # create Bio:Pipeline::Runnable::Genscan object
   my $genscan = Bio::Pipeline::Runnable::Genscan->new();
   $genscan->feat1($seq1);
 
   $genscan->analysis($analysis);
   $genscan->run();
   my @feat = $genscan->output();
   my $no = scalar(@feat);
   print "No of genes $no\n";
   my @subfeat = $feat[0]->predicted_protein();
   $no = scalar(@subfeat);
   print "No of Proteins $no \n";
   ok($feat[0]->isa("Bio::SeqFeatureI"));
   ok($subfeat[0]->isa("Bio::PrimarySeqI"));