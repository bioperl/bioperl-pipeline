# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::Runnable::Blast

=head1 SYNOPSIS

my $runnable = Bio::Pipeline::Runnable::Blast->new();
$runnable->analysis($analysis);
$runnable->run;
my $output = $runnable->output;

=head1 DESCRIPTION
This is the pipeline wrapper for ncbi blast that makes use of 
Bio::Tools::Run::StandAloneBlast module. It thus allows one to run
the following programs:
  1. blastall
  2. psiblast(blastpgp)
  3. bl2seq



Note:
  parameters are set in the parameters column inside the biopipeline
  analysis table in the following form "-p blastn -e 0.0001"
  For more detailed explanation of the parameters look go to 
  Bio::Tools::Run::StandAloneBlast or do a blastall|blastpgp - .|bl2seq on the command line

  The database for blastall is set using $self->analysis->db_file which
  is in turn set by runnable db where db_file is obtained from the analysis
  table. It is imperative this is present for the blast to function.


INPUT DATATYPES
The runnable currently accepts any Bio::Seq compliant objects

OUTPUT DATATYPES
The runnable currently returns the following output types:
  1) A SearchIO object for the blastall and blastpgp runs
  2) An AlignIO object for the bl2seq runs

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Blast;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq;
use Bio::Seq;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::StandAloneBlast;
use Bio::SearchIO;
use Bio::AlignIO;

@ISA = qw(Bio::Pipeline::RunnableI);

=head2 new 

Title   :   new 
Usage   :   $self->new()
Function:
Returns :
Args    :

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}

=head2 datatypes

Title   :   datatypes
Usage   :   $self->datatypes()
Function:   returns a hash of the datatypes required by the runnable
Returns :
Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dta = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my $dtb = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                            '-name'=>'sequence',
                                            '-reftype'=>'SCALAR');
    my %dts;
    $dts{seq1} = [];
    $dts{seq2} = [];
    push @{$dts{seq1}}, $dta;
    push @{$dts{seq1}}, $dtb;
    push @{$dts{seq2}}, $dta;
    push @{$dts{seq2}}, $dtb;
    return %dts;
}

=head2 seq1

Title   :   seq1
Usage   :   $self->seq1($seq)
Function:   get/set for query sequence
Returns :
Args    :

=cut

sub seq1{
    my ($self,$seq) = @_;
    if (defined($seq)){
        $self->{'_seq1'} = $seq;
    }
    return $self->{'_seq1'};
}

=head2 seq2

Title   :   seq2
Usage   :   $self->seq2($seq)
Function:   get/set for 2nd query sequence used in bl2seq
Returns :
Args    :

=cut
sub seq2{
    my ($self,$seq) = @_;
    if (defined($seq)){
        $self->{'_seq2'} = $seq;
    }
    return $self->{'_seq2'};
}

=head2 run 

Title   :   run 
Usage   :   $self->run()
Function:   execute blast calling StandAloneBlast.pm 
Returns :   Either a SearchIO or AlignIO object depending on the type of blast run
Args    :

=cut
sub run {
  my ($self) = @_;
  my $analysis = $self->analysis;
  my $blast_obj;
  my $return_type = 'hsp';

  if ($self->analysis->parameters){
    my @params = $self->parse_params($self->analysis->parameters);
    my %param = @params;
    if($param{'return_type'}){
        $return_type = $param{'return_type'};
        delete $param{'return_type'};
        @params = %param;
    }
    $blast_obj = Bio::Tools::Run::StandAloneBlast->new(@params);
  }
  else {
    $blast_obj = Bio::Tools::Run::StandAloneBlast->new();
  }

  $self->throw("Analysis not set") unless $analysis->isa("Bio::Pipeline::Analysis");
  
  my $program = $analysis->program || 'blastall';
  
  my $seq1 = $self->seq1;
  my $seq2 = $self->seq2;
  my $blast_report;

  #need to create a temp file for which to copy the blast output file. This
  #is because StandAloneBlast unlinks the file once leaving this subroutine.
  #We want the file to persist as long as this runnable is alive. It will unlink once
  #the runnable is destroyed.

  if($seq1 && $seq2 && ($program =~ /bl2seq/i)){
      my $IO = Bio::Root::IO->new();
      my ($fh,$newreport) = $IO->tempfile();
      $blast_report = $blast_obj->$program($seq1,$seq2);

      system("cp ". $blast_obj->o ." $newreport");
      my $alnio = Bio::AlignIO->new('-file'=>$newreport,
                                    '-format' => 'bl2seq');

      $self->output($alnio);                                    
  }
  elsif($seq1 && ($program =~ /blastall/i)) {
      my $IO = Bio::Root::IO->new();
      my ($fh,$newreport) = $IO->tempfile();
      $blast_obj->database($analysis->db_file);
      $blast_report = $blast_obj->$program($seq1);

      system("cp ". $blast_obj->o ." $newreport");
      my $searchio = Bio::SearchIO->new ('-format' => 'blast',
                                        '-file'   => $newreport);
      my @output;
      if($return_type =~/hit/i){
        while(my $result = $searchio->next_result){
            while(my $hit = $result->next_hit){
                push @output, $hit;
            }
        }
      }
      else {
        while (my $result = $searchio->next_result){
          while( my $hit = $result->next_hit ) {
            while( my $hsp= $hit->next_hsp ){
                $hsp->add_tag_value('analysis_parameters',$self->analysis->parameters);
                $hsp->add_tag_value('analysis_program',$self->analysis->program);
                $hsp->add_tag_value('analysis_db',$self->analysis->db);
                push @output,$hsp;
            }
          }
        }
      }
      
      $self->output(\@output);
  }
  elsif($seq1 && ($program =~/blastpgp/i)){
      my $IO = Bio::Root::IO->new();
      my ($fh,$newreport) = $IO->tempfile();
      $blast_obj->database($analysis->db_file);
      $blast_report = $blast_obj->$program($seq1);

      system("cp ". $blast_obj->o ." $newreport");
      my $searchio = Bio::SearchIO->new ('-format' => 'psiblast',
                                        '-file'   => $newreport);
      my @output;
      if($return_type=~/hit/i){
          while(my $result = $searchio->next_result){
            while(my $hit = $result->next_hit){

                $hit->add_tag_value('analysis_parameters',$self->analysis->parameters);
                $hit->add_tag_value('analysis_program',$self->analysis->program);
                $hit->add_tag_value('analysis_db',$self->analysis->db);
                push @output, $hit;
            }
        }
      }
      else {
        while (my $result = $searchio->next_result){
         while( my $hit = $result->next_hit ) {
           while( my $hsp = $hit->next_hsp ) {
              $hsp->add_tag_value('analysis_parameters',$self->analysis->parameters);
              $hsp->add_tag_value('analysis_program',$self->analysis->program);
              $hsp->add_tag_value('analysis_db',$self->analysis->db);
              push @output,$hsp;
           }
         }
        }
      }
      $self->output(\@output);

  }
  return $self->output;

}

1;
    
























