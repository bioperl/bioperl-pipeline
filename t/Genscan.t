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
      $NTESTS = 2;
      plan tests => $NTESTS;
  }
  END {
          for ( $Test::ntest..$NTESTS ) {
                skip("Genscan program not found. Skipping.\n",1);
          }
  }
  unless (Bio::Root::IO->exists_exe('genscan')){
   warn "Genscan program not found. Skipping tests $Test::ntest to $NTESTS.\n";
   exit(0);
  }

   # create and fill Bio::Seq object
   my $seqfile = Bio::Root::IO->catfile("t","data","Genscan.FastA");
   my $seq1 = Bio::Seq->new();
   my $seqstream = Bio::SeqIO->new(-file => $seqfile, -fmt => 'Fasta');
   $seq1 = $seqstream->next_seq();

   # create a analysis object (with just enough arguments for now that the runnable needs)
   if(! $ENV{'GENSCAN_DIR'}){
           warn("Need to define env variable GENSCAN_DIR to run test");
               exit(0);
   }
   my $paramfile = Bio::Root::IO->catfile($ENV{'GENSCAN_DIR'},"HumanIso.smat");
   my $parameters = "-MATRIX " . $paramfile;
   my $analysis = Bio::Pipeline::Analysis->new(-parameters => $parameters);
   
   # create Bio:Pipeline::Runnable::Genscan object
   my $genscan = Bio::Pipeline::Runnable::Genscan->new();


   $genscan->feat1($seq1);
 
   $genscan->analysis($analysis);
   eval{ 
       $genscan->run();
   };
   $@ && exit(0);
   my @feat = $genscan->output();
   my $no = scalar(@feat);
   my @subfeat = $feat[0]->predicted_protein();
   $no = scalar(@subfeat);
   ok($feat[0]->isa("Bio::SeqFeatureI"));
   ok($subfeat[0]->isa("Bio::PrimarySeqI"));
