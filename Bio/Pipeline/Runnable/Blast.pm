# Pipeline module for Bio::Pipeline::Runnable::Blast
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Blast
# originally written by Michele Clamp  <michele@sanger.ac.uk>
# Written in BioPipe by Shawn Hoon <shawnh@fugu-sg.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
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
Bio::Tools::Run::StandAloneBlast module. It thus allows one to run the
following programs:

  1. blastall
  2. psiblast(blastpgp)
  3. bl2seq


Note:

Parameters are set in the parameters column inside the biopipeline
analysis table in the following form "-p blastn -e 0.0001" For more
detailed explanation of the parameters look go to
Bio::Tools::Run::StandAloneBlast or do a blastall|blastpgp - .|bl2seq
on the command line

The database for blastall is set using
$self-E<gt>analysis-E<gt>db_file which is in turn set by runnable db
where db_file is obtained from the analysis table. It is imperative
this is present for the blast to function.


=head2 INPUT DATATYPES

The runnable currently accepts any Bio::Seq compliant objects

=head2 OUTPUT DATATYPES

The runnable currently returns the following output types:

=over 2

=item 1

A SearchIO object for the blastall and blastpgp runs

=item 2

An AlignIO object for the bl2seq runs

=back

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Blast
originally written by Michele Clamp, michele@sanger.ac.uk.
Written in BioPipe by Shawn Hoon, shawnh@fugu-sg.org.
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.


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
 Args    : -return_type => Hit or Hsp
           -formatdb    => boolean to run formatdb
           -formatdb_alphabet => dna or aa

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($return_type,$formatdb, $formatdb_alphabet) = 
      $self->_rearrange([qw(RETURN_TYPE FORMATDB FORMATDB_ALPHABET)],@args);
  $return_type && $self->return_type($return_type);
  $formatdb && $self->formatdb($formatdb);
  $formatdb_alphabet && $self->formatdb_alphabet($formatdb_alphabet);

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

sub formatdb_alphabet {
    my ($self,$val) = @_;
    if(defined($val)){
        $self->{'_formatdb_alphabet'} = $val;
    }
    return $self->{'_formatdb_alphabet'};
}
sub formatdb {
    my ($self,$val) = @_;
    if(defined($val)){
        $self->{'_formatdb'} = $val;
    }
    return $self->{'_formatdb'};
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
  $self->throw("Analysis not set") unless $analysis->isa("Bio::Pipeline::Analysis");
  my $blast_obj;
  my $return_type = $self->return_type || 'hsp';

  #initialize the StandAloneBlast Module
  my $result_dir;
  if($self->result_dir){
    my $dir = $self->result_dir;
    my $file;
    if(ref $self->seq1){
      $file = $self->seq1->id.".bls";
    }
    elsif($self->seq1) {
      #is a file name
      my $filename = (split /\//, $self->seq1)[-1];
      $file = $filename.".bls";
    }
    elsif($self->infile) {
      #is a file name
      my $filename = (split /\//, $self->infile)[-1];
      $file = $filename.".bls";
    }
    else {
      $file = "blastreport.bls";
    }
    $result_dir=Bio::Root::IO->catfile($dir,$file);
  }
  if($self->formatdb){
    $self->_setup_blastdb($analysis->db_file);
  }

  # the binary parameters
  my @params = $self->parse_params($analysis->analysis_parameters)
      if $analysis->analysis_parameters;
  push @params, ('output'=>$result_dir) if $result_dir;
  $blast_obj = Bio::Tools::Run::StandAloneBlast->new(@params);


  my $program = $analysis->program || 'blastall';

  #pass the path to the executable if program_file is set.
  $analysis->program_file && 
      $blast_obj->executable($analysis->program,$analysis->program_file,1);

  my $seq1 = $self->seq1;
  my $seq2 = $self->seq2;
  my $blast_report;
  if(!$seq1){
      $seq1 = $self->infile if $self->infile;
  }

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
                $hsp->add_tag_value('analysis_parameters',$self->analysis->analysis_parameters);
                $hsp->add_tag_value('analysis_program',$self->analysis->program);
                $hsp->add_tag_value('analysis_db',$self->analysis->db);
                $hsp->add_tag_value('description',$hit->description);
                $hsp->add_tag_value('num_ident',$hsp->{'_num_identical'});
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

sub _setup_blastdb {
    my ($self,$file) = @_;

    $file || return;

    #already formatted
    -e $file.".phr" && return;

    Bio::Root::IO->exists_exe('formatdb') || return;

    my $cmd = "formatdb -i ".$file;
    $cmd .= " -p F " if ($self->formatdb_alphabet =~/dna/i);
    my $status = system($cmd);
    $self->throw("Problems formatting db $file $!") if $status > 0;
    return;
}
1;

























