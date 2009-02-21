# Pipeline module for ProteinAnnotation Bio::Pipeline::Runnable::ProteinAnnotation
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::ProteinAnnotation
# originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
# Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Rewritten by Shawn Hoon to encapsulate all the protein runnables into one
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::Runnable::ProteinAnnotation

=head1 SYNOPSIS

 my @params = (-program=>"Profile");
 my $runnable = Bio::Pipeline::Runnable::ProteinAnnotation->new(@params); 
 $runnable->analysis($analysis);
 $runnable->run;
 my $output = $runnable->output;

=head1 DESCRIPTION

Runnable for ProteinAnnotation that encapsulates various protein annotation programs that include:

1) TMHMM 
2) SEG  
3) FingerPrintScan
4) PFScan        
5) SIGNALP      
6) HMMPFAM        

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to the
Bioperl mailing lists  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via
email or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.open-bio.org/

=head1 AUTHOR

 Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::ProteinAnnotation
 originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
 Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
 Rewritten by Shawn Hoon <shawnh@fugu-sg.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
 Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::ProteinAnnotation;
use vars qw(@ISA);
use strict;
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
 Function:   Returns the datatypes that the runnable requires.
 Returns :   It returns a hash of the different data types. 
 Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{protein_seq} = $dt1;

    return %dts;
}

=head2 protein_seq

 Title   : protein_seq
 Usage   : $self->protein_seq($seq)
 Function: 
 Returns :
 Args    :

=cut

sub protein_seq{
    my ($self,$seq) = @_;
    if (defined($seq)){
        $self->{'_protein_seq'} = $seq;
    }
    return $self->{'_protein_seq'};
}

=head2 run

 Title   :   run
 Usage   :   $self->run($seq)
 Function:   Runs ProteinAnnotation
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $program = $self->program;
  $program  = ucfirst $program;
  $program || $self->throw("Need to specify a protein annotation program");
  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  
  my $module = "Bio::Tools::Run::$program";
  eval {
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

  my $seq = $self->protein_seq;

  #Make the analysis parameters
  my @params = $self->parse_params($self->analysis->analysis_parameters);

  #make the output file path if result_dir is provided
  my $result_dir;
  if($self->result_dir){
    my $dir = $self->result_dir;
    my $file;
    if(ref $self->seq){
      my $suffix = $self->file_suffix || ".pfeat";
      $file = $self->seq->id.$suffix;
    }
    elsif($self->seq) {
      #is a file name
      my $filename = (split /\//, $self->seq)[-1];
      $file = $filename.$self->file_suffix;
    }
    else {
      $file = "$program.pfeat";
    }
    $result_dir=Bio::Root::IO->catfile($dir,$file);
  }
  push @params,('outfile'=>$result_dir) if $result_dir;

  #add db_file if provided
  my $db_file = $self->analysis->db_file;
  push @params, ("DB"=> $db_file) if $db_file;

  my $factory;
  $factory = $module->new(@params);
  my $program_file = $self->analysis->program_file;
  $factory->executable($program_file) if $program_file;

  my @features;
  eval {
    @features  = $factory->predict_protein_features($seq);
  };

	$self->throw("Problems running predict_protein_featuers due to $@") if $@;

  return unless(scalar @feature);
  if($features[0]->isa("Bio::SearchIO")){
    @features = $self->_return_feat($features[0]);
  }

  $self->output(\@features);
  
  return \@features;

}

sub _return_feat {
  my ($self,$sio) = @_;
  my @feat;
  while (my $result = $sio->next_result){
    while(my $hit = $result->next_hit){
      while (my $hsp = $hit->next_hsp){
       push @feat, $hsp;
      }
    }
  } 
  return @feat;
}
1;



