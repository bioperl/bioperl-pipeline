# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon 
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod 
#
# =head1 NAME
#
# Bio::Pipeline::Runnable::DBA
#
=head1 SYNOPSIS

=head1 DESCRIPTION
Runnable for Dna Block Aligner program by Ewan Birney available at
ftp://ftp.sanger.ac.uk/pub/birney/wise2/

=head1 CONTACT

Describe contact details here

=head1 APPENDIX


=cut

package Bio::Pipeline::Runnable::DBA;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq; 
use Bio::SeqFeature::FeaturePair;
use Bio::SeqFeature::Generic;
use Bio::SeqI;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}
=head2 datatypes

Title   :   datatypes 
Usage   :   $self->datatypes
Function:   Returns the datatypes that the runnable requires. This is used by the Runnable DB to 
            match the inputs to the corresponding. 
Returns :   It returns a hash of the different data types. The key of the hash is the name of the 
            get/set method used by the RunnableDB to set the input
Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my $dt2 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{feat1} = $dt1;
    $dts{feat2} = $dt2;

    return %dts; 
}

=head2 feat1
  
Title   :   feat1
Usage   :   $self->feat1($seq)
Function:   
Returns :   
Args    :   

=cut

sub feat1{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat1'} = $feat;
    }
    return $self->{'_feat1'};
}
=head2 feat2
  
Title   :   feat2
Usage   :   $self->feat2($seq)
Function:   
Returns :   
Args    :   

=cut

sub feat2{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat2'} = $feat;
    }
    return $self->{'_feat2'};
}

  

=head2 params
  
Title   :   params
Usage   :   $self->params($seq)
Function:   Get/set method for params 
Returns :   String 
Args    :   String 

=cut

sub params{
    my ($self,$params) = @_;
    if (defined($params)){
        $self->{'_params'} = $params;
    }
    return $self->{'_params'};
}

=head2 dba
  
Title   :   dba
Usage   :   $self->dba($seq)
Function:   Get/set method for dba 
Returns :   String 
Args    :   String 

=cut

sub dba{
    my ($self,$dba) = @_;
    if (defined($dba)){
        $self->{'_dba'} = $dba;
    }
    return $self->{'_dba'};
}

=head2 alignpair
  
Title   :   alignpair
Usage   :   $self->alignpair($seq)
Function:   Get/set method for alignpair 
Returns :   Bio::SeqFeature::FeaturePair 
Args    :   Bio::SeqFeature::FeaturePair 

=cut

sub alignpair{
    my ($self,$alignpair) = @_;
    if (defined($alignpair)){
        $self->{'_alignpair'} = $alignpair;
    }
    return $self->{'_alignpair'};
}

=head2 run
  
Title   :   run
Usage   :   $self->run($seq)
Function:   Runs DBA 
Returns :   
Args    :  

=cut
sub run {
  my ($self) = @_;
  my $seq1 = $self->feat1->seq ;
  my $seq2 = $self->feat2->seq;

  my $params = $self->params;
  my $dba = $self->dba;
  if (!defined $dba) {
    $dba =  $self->analysis->program_file;
  }

  my $infile1 = "/tmp/$ENV{USER}-$$.dba_1";
  my $infile2 = "/tmp/$ENV{USER}-$$.dba_2";
  my $resultfile = "/tmp/_dbaresult_".$$;
  my $out1 = Bio::SeqIO->new(-file => ">$infile1",'format'=>'fasta');
  my $out2 = Bio::SeqIO->new(-file => ">$infile2",'format'=>'fasta');

  print $out1->write_seq($seq1);
  print $out2->write_seq($seq2);
  $out1->close;
  $out2->close;
  my $command = "$dba $infile1 $infile2 > $resultfile";
  eval {
    print STDERR "Running command $command \n";
    system($command);
    $self->parse_results($resultfile);
  };
# delete tmp files
  unlink $infile1;
  unlink $infile2;
  unlink $resultfile;

}

=head2 parse_results
  
  Title   :   parse_results
  Usage   :   $self->parse_results($seq)
  Function:   Parse results into a feature pair 
  Returns :   Bio::SeqFeature::FeaturePair 
  Args    :   filepath to results 

=cut
  
sub parse_results {
  my($self,$resultfile) = @_;
  print $resultfile;
  my ($score,$feat1_start,$feat1_end,$feat2_start,$feat2_end,$pid);
	my ($global_end1,$global_end2);
	$global_end1 	 = $self->feat1->end;
	$global_end2	 = $self->feat2->end;

  #do the parsing	
  if (-e $resultfile) {
    open(DBA, "<$resultfile") || $self->throw("Error opening $resultfile \n");
  }
  else {
    $self->throw("$resultfile doesn't exist.\n");
  }
  while (<DBA>){
    print $_;   
    if (/score =\s+(\S+)/){
      $score = $1;
    }
    if (/\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%/){
      $feat1_start = $1;
      $feat1_end = $2;
      $feat2_start = $3;
      $feat2_end = $4;
      $pid = $5;
    }
  }
  if (!$feat1_start){#no alignment
      $self->warn("No alignment for ".$self->feat1->seqname);
      return;
  }

 #create the coordinates. Note here have to map back to original coordinates if
 #negative strand since what was given was reverse complemented sequence
 my ($feature1_start,$feature1_end,$feature2_start,$feature2_end);
 if ($self->feat1->strand < 0){

		 $feature1_start = $self->feat1->end - $feat1_end;
		 $feature1_end = $self->feat1->end - $feat1_start;
 }
 else {
		 $feature1_start = $feat1_start + $self->feat1->start;
		 $feature1_end   = $feat1_end + $self->feat1->start;
 }
 if ($self->feat2->strand < 0){
		 $feature2_start = $self->feat2->end - $feat2_end;
		 $feature2_end = $self->feat2->end - $feat2_start;
 }
 else {
		 $feature2_start = $self->feat2->start + $feat2_start;
		 $feature2_end = $self->feat2->start + $feat2_end;
	}

 
  my $feat1 = Bio::SeqFeature::Generic->new (-seqname => $self->feat1->seqname,
                                             -strand  => $self->feat1->strand,
                                             -score   => $score,
                                             -start   => $feature1_start,
                                             -end     => $feature1_end,
                                             -frame   => $self->feat1->frame,
                                             -source  => "dba",
                                             -primary => $self->feat2->seqname,
                                             -tag     => {
                                                          percent_id=>$pid});

 my $feat2 = Bio::SeqFeature::Generic->new (-seqname => $self->feat2->seqname,
                                             -strand  => $self->feat2->strand,
                                             -score   => $score,
                                             -start   => $feature2_start,
                                             -end     => $feature2_end,
                                             -frame   => $self->feat2->frame,
                                             -source  => "dba",
                                             -primary => $self->feat2->seqname,
                                             -tag     => {percent_id=>$pid});


 my $featurepair = Bio::SeqFeature::FeaturePair->new(-feature1 => $feat1,
                                                  -feature2 => $feat2);
 
 print "#####\n".$featurepair->gff_string."\n";
 $self->alignpair($featurepair);
 return $featurepair;
}
    
=head2 output
  
Title   :   output
Usage   :   $self->output($seq)
Function:   Get/set method for output 
Returns :   Bio::SeqFeature::FeaturePair 
Args    :   Bio::SeqFeature::FeaturePair 

=cut

sub output{
    my ($self) = @_;
    
    return $self->alignpair;
}

  





















    
