#!/usr/local/bin/perl

use strict;
use Bio::SeqIO;
use Bio::Seq;
use Bio::Pipeline::Runnable::Blat;
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
                skip("Blat program not found. Skipping.\n",1);
          }
  }
  unless (Bio::Root::IO->exists_exe('blat')){
   warn "Blat program not found. Skipping tests $Test::ntest to $NTESTS.\n";
   exit(0);
  }

   # create and fill Bio::Seq object
   my $seqfile = Bio::Root::IO->catfile("t","data","blat_dna.fa");
   my $seq1 = Bio::Seq->new();
   my $seqstream = Bio::SeqIO->new(-file => $seqfile, -fmt => 'Fasta');
   $seq1 = $seqstream->next_seq();

   # create a analysis object (with just enough arguments for now that the runnable needs)
   my $analysis = Bio::Pipeline::Analysis->new(-db_file=> $seqfile);
   
   # create Bio:Pipeline::Runnable::Blat object
   my $blat = Bio::Pipeline::Runnable::Blat->new();


   $blat->feat1($seq1);
 
   $blat->analysis($analysis);
   eval{ 
       $blat->run();
   };
   $@ && exit(0);
   my @feat = $blat->output();
   my $no = scalar(@feat);
   ok $no, 2;
   my @subfeat = $feat[0]->get_SeqFeatures();
   $no = scalar(@subfeat);
   ok($feat[0]->isa("Bio::Search::HSP::HSPI"));
   
