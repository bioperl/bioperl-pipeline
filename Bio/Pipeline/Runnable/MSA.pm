# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
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
=head1 NAME

Bio::Pipeline::Runnable::MSA - The pipeline wrapper for running
Multiple Sequence Alignment programs, now supportes ClustalW and
TCoffee


=head1 SYNOPSIS

  # For running a multiple alignments on an array of seq objects:

  my $runnable = Bio::Pipeline::Runnable::MSA->new();
  my $analysis = new Bio::Pipeline::Analysis
      (-ID             => 1,
       -PROGRAM        => "clustalw",
       -PROGRAM_FILE   => "/usr/local/bin/clustalw",
       -RUNNABLE       => "Bio::Pipeline::Runnable::MSA",
       -RUNNABLE_PARAMETERS=>"-program Clustalw"
       -LOGIC_NAME     => "Clustalw"
       -OUTPUT_HANDLER => $output_handler );

  $runnable->analysis($analysis);

  my $seq = Bio::PrimarySeq->new
      ( -seq => 'ATGGGGTGGGCGGTGGGTGGTTTGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG',
	-id  => '1',
	-accession_number => 'X78121',
	-alphabet => 'dna',
	-is_circular => 1
      );
  my $seq2 = Bio::PrimarySeq->new
      ( -seq => 'CCCCATGGGGTGGGCGGTGGGTGGTTTGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG',
	-id  => '2',
	-accession_number => 'X78121',
	-alphabet => 'dna',
	-is_circular => 1
      );
  my @seq;
  push @seq,$seq;
  push @seq,$seq2;
  $runnable->seq(\@seq);
  $runnable->run;
  my $output = $runnable->output; #Returns a SimpleAlign object

  # OR do a profile alignment with a single sequence and an alignment object

  my $align = $runnnable->output;
  $runnable->align($align);
  my $seq3 = Bio::PrimarySeq->new
      ( -seq => 'CCCGTGGGTGGTTTGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG',
	-id  => '3',
	-accession_number => 'X78121',
	-alphabet => 'dna',
	-is_circular => 1
      );
  $runnable->seq($seq3);
  my $analysis = new Bio::Pipeline::Analysis
          (-ID             => 2,
           -PROGRAM        => "clustalw",
	   -PROGRAM_FILE   => "/usr/local/bin/clustalw",
	   -RUNNABLE       => "Bio::Pipeline::Runnable::MSA",
	   -RUNNABLE_PARAMETERS       => "-program Clustalw -align_type profile_align",
	   -LOGIC_NAME     => "Clustalw"
	   -OUTPUT_HANDLER => $output_handler );

  $runnable->run;
  my $output = $runnable->output; #Returns a SimpleAlign object

  # OR do a profile alignment with 2 alignment objects

  $runnable->align($aln1,$aln2); #2 Simple Align objects

  $runnable->run;
  my $output = $runnable->output;


=head1 DESCRIPTION

This provides a 'pipelineable' interface to the MSA programs making use of
the Bio::Tools::Run::Alignment::* modules.

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::MSA;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;

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
  my ($align_type) = $self->_rearrange([qw(ALIGN_TYPE)],@args);
  $align_type ||='align';
  $self->align_type($align_type);

  return $self;

}

=head2 align_type

 Title   :   align_type
 Usage   :   $self->align_type()
 Function:   get/set for alignment type either align or profile_align
 Returns :   string
 Args    :   string

=cut

sub align_type {
  my ($self,$val) = @_;
  if($val){
    $self->{'_align_type'} = $val;
  }
  return $self->{'_align_type'};
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
                                        '-reftype'=>'ARRAY');
  my $dtb = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SimpleAlign',
                                         '-name'=>'alignment',
                                         '-reftype'=>'ARRAY');

  my $dtc = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SimpleAlign',
                                         '-name'=>'alignment',
                                         '-reftype'=>'SCALAR');
  my $dtf = Bio::Pipeline::DataType->new('-object_type'=>'File',
                                         '-name'=>'sequence',
                                         '-reftype'=>'SCALAR');

  my %dts;
  $dts{seq} = $dta;
  #get/set for align can hold either an array of alignments (for profile alignment between
  #2 alignments) or a single alignment for a profile alignment between a profile alignment and
  #a sequence object
  $dts{align} = [];
  push @{$dts{align}},$dtb;
  push @{$dts{align}},$dtc;
  $dts{infile} = $dtf;


  return %dts;

}

=head2 seq

 Title   :   seq
 Usage   :   $self->seq(\@seq)
 Function:   get/set to hold a reference to an array of sequences/single 
             sequence for multiple alignment/profile alignment
 Returns :
 Args    :

=cut

sub seq {
    my ($self,$seq) = @_;
    if(defined $seq){
        $self->{'_seq'} = $seq;
    }
    return $self->{'_seq'};
}

=head2 align

 Title   :   align
 Usage   :   $self->align(\@align)
 Function:   get/set to hold a reference to an array of alignments/single 
             alignment for profile alignment
 Returns :
 Args    :

=cut

sub align {
    my ($self,$align) = @_;
    if(defined $align){
        $self->{'_align'} = $align;
    }
    return $self->{'_align'};
}

=head2 run

 Title   :   run
 Usage   :   $self->run()
 Function:   execute
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $program = $self->program;
  $program || $self->throw("Need to specify a alignment program");
  my $module = "Bio::Tools::Run::Alignment::$program";
  eval{
   $self->_load_module($module);
  };
  if($@){
      print STDERR <<END;
$self:$module cannot be found.
Exception $@
Problems loading, pls check your PERL5LIB path
END
;
}

  my $result_dir;
  my $analysis = $self->analysis;
  if($self->result_dir){
    my $dir = $self->result_dir;
    my $file;
    if(ref $self->seq){
      my $suffix = $self->file_suffix || ".aln";
      $file = $self->seq->id.$suffix;
    }
    elsif($self->seq) {
      #is a file name
      my $filename = (split /\//, $self->seq)[-1];
      $file = $filename.$self->file_suffix;
    }
    else {
      $file = "$program.aln";
    }
    $result_dir=Bio::Root::IO->catfile($dir,$file);
  }
  my @params = $self->parse_params($analysis->analysis_parameters) if $analysis->analysis_parameters;
  push @params, ('outfile'=>$result_dir) if $result_dir;
  my $factory  = $module->new(@params);
 
  $factory->executable($analysis->program_file) if $analysis->program_file;
  $factory->quiet(1);

  my $align_type = $self->align_type;
  my $aln;
  ($align_type =~ /align|profile_align/i) || $self->throw("MSA needs either program to be set as align or profile_align as runnable parameters");

  #get input 
  my $seq;
  if($self->seq){
      $seq = $self->seq;
  }
  elsif($self->infile) {
    $seq = $self->infile;
  }
  else {
      $self->throw("No input supplied");
  }
  
  if ($align_type eq "align"){
      $aln    = $factory->align($seq);
  }
  else {
      my $subaln = $self->align;
      $subaln || $self->throw("Need at least one alignment to run profile align");

      if (ref($subaln) eq "ARRAY" && (scalar(@{$subaln}) == 2)){
            $aln = $factory->profile_align($subaln->[0],$subaln->[1]);
      }
      else {
          $subaln->isa("Bio::Align::AlignI") || $self->throw("Need an Align object to do profile_align");
          my $seq = $self->seq;
          $seq || $self->throw("Need a Bio::Seq object to do profile_align");
          $aln = $factory->profile_align($subaln,$seq);
      }
  }
  $self->output($aln);
  return $self->output;
}


1;
