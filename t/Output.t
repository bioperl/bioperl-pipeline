#!/usr/local/bin/perl


#add test dir to lib search path
    BEGIN {
    use lib 't';
    use Test;
    plan tests => 7;
    }

    use BiopipeTestDB;
    use Bio::Pipeline::SQL::DBAdaptor;
    use Bio::SeqIO;
    use Bio::Seq;

    my $biopipe_test = BiopipeTestDB->new();

    ok $biopipe_test;

    $biopipe_test->do_sql_file("t/data/init.sql");


    my $dba = $biopipe_test->get_DBAdaptor();
    ok $dba;


    my $analysisAdaptor = $dba->get_AnalysisAdaptor;
    ok $analysisAdaptor;

    my $analysis = $analysisAdaptor->fetch_by_dbID(1);
    ok $analysis;
    
    my ($io) = $analysis->output_handler;
     ok defined $io;


   my @seq;
   my $seq = new Bio::Seq(-seq=>"CCCCCCCCCCCCCCCCCCCCCCCCC",
                           -id=>"test_output");

   push @seq, $seq;

  eval {
    $io->write_output($seq,@seq); 
  };
  my $err = $@;
  ok $err, "";

  my $seqio = Bio::SeqIO->new(-file=>"t/data/testout.fa",-format=>'Fasta');
  my $read_seq = $seqio->next_seq;
  ok ($read_seq->seq eq $seq->seq);
  


