# Pipeline module for Bio::Pipeline::Runnable::Fasta
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Blast
# originally written by Michele Clamp  <michele@sanger.ac.uk>
# Written in BioPipe by Jason Stajich <jason@bioperl.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
# and Jason Stajich
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::Runnable::Fasta

=head1 SYNOPSIS

  my $runnable = Bio::Pipeline::Runnable::Fasta->new();
  $runnable->analysis($analysis);
  $runnable->run;
  my $output = $runnable->output;

=head1 DESCRIPTION

This is the pipeline wrapper for Bill Pearson's fasta,ssearch
executables \ that makes use of Bio::Tools::Run::StandAloneFasta
module. It thus allows one to run the following programs:

  1. fasta
  2. tfasta
  3. tfastx
  4. tfasty
  5. fastx
  6. fasty 
  7. ssearch
  8. prss

Note:

parameters are set in the parameters column inside the biopipeline
analysis table in the following form " -E 0.0001 -S" For more detailed
explanation of the parameters look go to
Bio::Tools::Run::Alignment::StandAloneFasta or do a 'man fasta3'

The database for Fasta is set using $self-E<gt>analysis-E<gt>db_file
which is in turn set by runnable db where db_file is obtained from the
analysis table. It is imperative this is present for the fasta to
function.


=head2 INPUT DATATYPES

The runnable currently accepts any Bio::Seq compliant objects

=head2 OUTPUT DATATYPES

The runnable currently returns the following output types:

  1) A SearchIO object for the Fasta/ssearch output

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Fasta
originally written by Michele Clamp, michele@sanger.ac.uk.
Written in BioPipe by Jason Stajich, jason@bioperl.org.
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Fasta;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq;
use Bio::Seq;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Alignment::StandAloneFasta;
use Bio::SearchIO;

@ISA = qw(Bio::Pipeline::RunnableI);

=head2 new

 Title   :   new
 Usage   :   $self->new()
 Function:
 Returns :
 Args    : -return_type => 'hsp' or 'Hit'

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($return_type) = $self->_rearrange([qw(RETURN_TYPE)],@args);

  $return_type && $self->return_type($return_type);
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
    my $dtf = Bio::Pipeline::DataType->new('-object_type'=>'File',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');


    my %dts;
    $dts{seq1} = [];
    $dts{seq2} = [];
    push @{$dts{seq1}}, $dta;
    push @{$dts{seq1}}, $dtb;
    push @{$dts{seq2}}, $dta;
    push @{$dts{seq2}}, $dtb;
    $dts{infile} = $dtf;
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

sub return_type {
    my ($self,$val) = @_;
    if(defined($val)){
        $self->{'_return_type'} = $val;
    }
    return $self->{'_return_type'};
}


=head2 run

 Title   :   run
 Usage   :   $self->run()
 Function:   execute fasta calling StandAloneFasta
 Returns :   SearchIO 
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $analysis = $self->analysis;
  $self->throw("Analysis not set") unless $analysis->isa("Bio::Pipeline::Analysis");
  my $fasta_obj;
  my $return_type = $self->return_type || 'hsp';

  #initialize the StandAloneFasta Module
  my $result_dir;
  if($self->result_dir){
    my $dir = $self->result_dir;
    my $file;
    if(ref $self->seq1){
      $file = $self->seq1->id.".FASTA";
    }
    elsif($self->seq1) {
      #is a file name
      my $filename = (split /\//, $self->seq1)[-1];
      $file = $filename.".FASTA";
    }
    elsif($self->infile) {
      #is a file name
      my $filename = (split /\//, $self->infile)[-1];
      $file = $filename.".FASTA";
    }
    else {
      $file = "fastareport.FASTA";
    }
    $result_dir = Bio::Root::IO->catfile($dir,$file);
  }

  # the binary parameters
  my @params = $self->parse_params($analysis->analysis_parameters) 
      if $analysis->analysis_parameters;
  push @params, ('O'=>$result_dir) if $result_dir;
  $fasta_obj = Bio::Tools::Run::Alignment::StandAloneFasta->new(@params);

  my $program = $analysis->program || 'fasta34';

  # {ass the path to the executable if program_file is set.
  $analysis->program_file && $fasta_obj->executable($analysis->program,
						    $analysis->program_file,1);
  
  my $seq1 = $self->seq1;
  my $seq2 = $self->seq2;
  my $fasta_report;

  if( !$seq1 ){
      $seq1 = $self->infile if $self->infile;
  }

  # Need to create a temp file for which to copy the fasta output file. This
  # is because StandAloneFasta unlinks the file once leaving this subroutine.
  # We want the file to persist as long as this runnable is alive. 
  # It will unlink once the runnable is destroyed.
  
  my $IO = Bio::Root::IO->new();
  my ($fh,$newreport) = $IO->tempfile();
  
  $fasta_obj->database($analysis->db_file);
  
  $fasta_report = $fasta_obj->run($seq1);
  
  # change this to be system independent!!
  system("cp ". $fasta_obj->O ." $newreport");
  my $searchio = Bio::SearchIO->new ('-format' => 'fasta',
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
		  $hsp->add_tag_value('analysis_parameters',$self->analysis->analysis_parameters);
		  $hsp->add_tag_value('analysis_program',$self->analysis->program);
		  $hsp->add_tag_value('analysis_db',$self->analysis->db);
		  push @output,$hsp;
	      }
          }
      }
  }

  $self->output(\@output);
  return $self->output;
}

1;

























