# Pipeline Runnable for Genewise Bio::Pipeline::Runnable::Genewise
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genewise
# originally written by Michele Clamp  <michele@sanger.ac.uk>
# Written in BioPipe by Fugu student intern Low Yik Jin
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::Runnable::Genewise

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is based on Genewise.
Genewise takes a query protein sequence and a target genomic region 
and predicts genes on the genomic region. 
The resulting output is parsed to produce a set of Bio::SeqFeatures. 

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution. Bug reports can be submitted via email
    or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR 

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genewise
originally written by Michele Clamp <michele@sanger.ac.uk>

Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

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

sub cigar {
    my ($self,$value) = @_;
    if($value){
        $self->{'_cigar'} = $value;
    }
    return $self->{'_cigar'};
}

sub contig_id {
    my ($self,$value) = @_;
    if($value){
        $self->{'_contig_id'} = $value;
    }
    return $self->{'_contig_id'};
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
    #run genewise       
    $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
    my $factory;

    my @params = $self->parse_params($self->analysis->analysis_parameters);
    $factory = Bio::Tools::Run::Genewise->new(@params);
    $factory->executable($self->analysis->program_file) if $self->analysis->program_file;
  
    my @genes;
    eval {
     @genes = $factory->predict_genes($seq1, $seq2);
    };
    @genes = $self->_map_genes(@genes);

    $self->output(\@genes);
    return \@genes;
}


sub _map_genes {
    my ($self,@genes) = @_;
    $self->cigar || return @genes;

    my $str = $self->cigar;
    my ($strand,$coord) = split(',',$str);
    my ($start,$end)    = split('-',$coord);
    my $match1 = Bio::Location::Simple->new ( -start => 1, -end => ($end-$start+1), -strand=>$strand );
    my $match2 = Bio::Location::Simple->new ( -start => $start, -end => $end, -strand=>$strand );
    my $pair = Bio::Coordinate::Pair->new(-in => $match1, -out => $match2);

    foreach my $g(@genes){
      $self->contig_id && $g->add_tag_value('contig_id'=>$self->contig_id);
      $g->location($pair->map($g->location)->each_location);
      foreach my $t($g->transcripts){
        $t->location($pair->map($t->location)->each_location);
        foreach my $e($t->exons){
          $e->location($pair->map($e->location)->each_location);
          my ($support_feature) = $e->each_tag_value('supporting_feature');
          $support_feature->location($pair->map($support_feature->location)->each_location);
        }
      }
   }
    return @genes;
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
	



