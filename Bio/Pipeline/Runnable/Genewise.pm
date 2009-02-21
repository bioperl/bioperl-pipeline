# Pipeline Runnable for Genewise Bio::Pipeline::Runnable::Genewise
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genewise
# originally written by Michele Clamp  <michele@sanger.ac.uk>
# Written in BioPipe by Fugu student intern Low Yik Jin
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::Runnable::Genewise

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is based on Genewise.  Genewise takes a query protein
sequence and a target genomic region and predicts genes on the genomic
region.  The resulting output is parsed to produce a set of
Bio::SeqFeatures.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution. Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR 

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genewise
originally written by Michele Clamp, michele@sanger.ac.uk.

# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Runnable::Genewise;
use vars qw(@ISA);
use strict;
use Bio::Root::RootI;
use Bio::Pipeline::DataType;
use Bio::Tools::Run::Genewise;
use FileHandle;
use Bio::PrimarySeq;
use Bio::SeqFeature::FeaturePair;
use Bio::SeqFeature::Generic;
use Bio::SeqI;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::RunnableI;
use Bio::Location::Simple;
use Bio::Coordinate::Pair;

@ISA = qw(Bio::Pipeline::RunnableI);


sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);    
    return $self;
}

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');
    my $dt2 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');

    my %dt;
    $dt{query_pep} = $dt1;
    $dt{target_dna} = $dt2;
    return %dt;
}

sub query_pep {
    my ($self, $seq) = @_;
    if ($seq)
    {
        unless ($seq->isa("Bio::PrimarySeqI") || $seq->isa("Bio::SeqI")) 
        {
            $self->throw("Query peptide isn't a Bio::Seq or Bio::PrimarySeq");
        }
        $self->{'_query_pep'} = $seq ;
    }
    return $self->{'_query_pep'};
}
sub genewise_strand {
  my ($self,$strand) = @_;
  if($strand){
    $self->{'_genewise_strand'} = $strand;
  }
  return $self->{'_genewise_strand'};
}
sub target_dna {
    my ($self, $seq) = @_;
    if ($seq)
    {
        unless ($seq->isa("Bio::PrimarySeqI") || $seq->isa("Bio::SeqI"))
        {
            $self->throw("Target dna isn't a Bio::Seq or Bio::PrimarySeq");
        }
        $self->{'_target_dna'} = $seq ;
    }
    return $self->{'_target_dna'};
}


=head2 run

  Title   :  run
  Usage   :   $obj->run()
  Function:   Runs Genewise and creates array seqfeatures
  Returns :   none
  Args    :   none

=cut

sub run {

    my ($self) = @_;
     #check seq
    my $seq1 = $self->query_pep() || $self->throw("Query protein sequence required for Genewise\n");
    my $seq2 = $self->target_dna() || $self->throw("Target dna sequence required for Genewise\n");
    my $genewise_strand = $self->genewise_strand || 1;
    #run genewise       
    $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
    my $factory;

    my @params = $self->parse_params($self->analysis->analysis_parameters);
    if(($genewise_strand < 0) && ($self->analysis->analysis_parameters !~ /trev/)){
    push @params, ("trev"=>1);
    }
    #default to quieten progress bar
    push @params, ("quiet"=>1);
    $factory = Bio::Tools::Run::Genewise->new(@params);
    $factory->executable($self->analysis->program_file) if $self->analysis->program_file;
 
    print "Running Genewise ...\n";
    print "Peptide Length is ".$seq1->length."\n";
    print "Dna Length is ".$seq2->length."\n";
    print "Running with parameters ".join(" ",@params)."\n"; 
    my @genes;
    eval {
     @genes = $factory->predict_genes($seq1, $seq2);
    };
    print scalar(@genes) ." predicted \n";
    $self->output(\@genes);
    return \@genes;
}

=head2 output

  Title   :   output
  Usage   :   $self->output($seq)
  Function:   Get/set method for output
  Returns :   A Bio::Seqfeature::Gene:GeneStructure object
  Args    :   A Bio::Seqfeature::Gene:GeneStructure object

=cut

sub output{
    my ($self,$gene) = @_;
    if(defined $gene){
      (ref($gene) eq "ARRAY") || $self->throw("Output must be an array reference.");
      $self->{'_gene'} = $gene;
    }
    return @{$self->{'_gene'}};
}

1;
	



