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
# Bio::EnsEMBL::Pipeline::Runnable::DBA
#
=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX


=cut

package Bio::Pipeline::Runnable::DBA;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::EnsEMBL::Pipeline::RunnableI;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Pipeline::Runnable::FeatureFilter;
use Bio::PrimarySeq; 
use Bio::Seq;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);



  return $self;

}

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::EnsEMBL::SeqFeature',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my $dt2 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::EnsEMBL::SeqFeature',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{feat1} = $dt1;
    $dts{feat2} = $dt2;

    return %dts; 
}

sub inputs {
    my ($self,$value) = @_;
    if ($value) {
        if (ref($value) eq "ARRAY"){
            $self->{'_inputs'} = $value;
        }
        else {
            my @tmp;
            push @tmp, $value;
            $self->{'_inputs'} = \@tmp;
        }
    }
    return $self->{'_inputs'};
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
Returns :   Bio::EnsEMBL::FeaturePair 
Args    :   Bio::EnsEMBL::FeaturePair 

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
  $self->data_match;
  my $seq1 = $self->feat1->seq ;
  my $seq2 = $self->feat2->seq;

  my $params = $self->params;
  my $dba = $self->dba;
  if (!defined $dba) {
    $dba =  $self->find_executable('dba');
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
  Returns :   Bio::EnsEMBL::FeaturePair 
  Args    :   filepath to results 

=cut
  
sub parse_results {
  my($self,$resultfile) = @_;
  my ($score,$feat1_start,$feat1_end,$feat2_start,$feat2_end,$pid);
  my $featpair = $self->featpair();
  if (-e $resultfile) {
    open(DBA, "<$resultfile") || $self->throw("Error opening $resultfile \n");
  }
  else {
    $self->throw("$resultfile doesn't exist.\n");
  }
  while (<DBA>){
   
    if (/score = (\d+.\d+)/){
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
      $self->warn("No alignment for ".$featpair->seqname);
      return;
  }
  my $analysis_obj    = new Bio::EnsEMBL::Analysis
                      (-db              => undef,
                       -db_version      => undef,
                       -program         => "dba",
                       -program_version => "1",
                       -gff_source      =>"dba",
                       -gff_feature     =>"similarity" 
                       );
  
  my $feat1 = Bio::EnsEMBL::SeqFeature->new (-seqname => $featpair->feature1->seqname,
                                             -strand  => $featpair->feature1->strand,
                                             -score   => $score,
                                             -start   => $feat1_start,
                                             -end     => $feat1_end,
                                             -frame   => $featpair->feature1->frame,
                                             -source_tag => "dba",
                                             -primary_tag => $featpair->feature2->seqname,
                                             -percent_id =>$pid,
                                             -analysis=>$analysis_obj);
 my $feat2 = Bio::EnsEMBL::SeqFeature->new (-seqname => $featpair->feature2->seqname,
                                             -strand  => $featpair->feature2->strand,
                                             -score   => $score,
                                             -start   => $feat2_start,
                                             -end     => $feat2_end,
                                             -frame   => $featpair->feature2->frame,
                                             -source_tag => "dba",
                                             -primary_tag => $featpair->feature2->seqname,
                                             -percent_id=>$pid,
                                             -analysis_id=>$analysis_obj);


 my $featurepair = Bio::EnsEMBL::FeaturePair->new(-feature1 => $feat1,
                                                  -feature2 => $feat2);
 
 $self->alignpair($featurepair);
 return $featurepair;
}
    
=head2 output
  
Title   :   output
Usage   :   $self->output($seq)
Function:   Get/set method for output 
Returns :   Bio::EnsEMBL::FeaturePair 
Args    :   Bio::EnsEMBL::FeaturePair 

=cut

sub output{
    my ($self) = @_;
    return $self->alignpair;
}

  





















    
