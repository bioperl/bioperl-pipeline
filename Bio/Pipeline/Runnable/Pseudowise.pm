# Cared for by Kiran  <kiran@fugu-sg.org>
#
# Copyright Kiran 
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::Runnable::Pseudowise

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is based on Pseudowise.
Pseudowise takes a query protein sequence, corresponding cdna sequence and a target genomic region 
and predicts pseudogenes on the genomic region. 
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

=head1 AUTHOR -Kiran 

Email kiran@fugu-sg.org

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Runnable::Pseudowise;
use vars qw(@ISA);
use strict;
use Bio::Root::RootI;
use Bio::Pipeline::DataType;
use Bio::Tools::Run::Pseudowise

@ISA = qw(Bio::Pipeline::RunnableI);


sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);    

    #$self->query_pep($query_pep);
    #$self->query_cdna($query_cdna);
    #$self->target_dna($target_dna);

    return $self;
}

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');
    my $dt2 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');
    my $dt3 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');

    my %dt;
    $dt{query_pep} = $dt1;
    $dt{query_cdna} = $dt2;
    $dt{target_dna} = $dt3;
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
sub query_cdna {
    my ($self, $seq) = @_;
    if ($seq)
    {
        unless ($seq->isa("Bio::PrimarySeqI") || $seq->isa("Bio::SeqI"))
        {
            $self->throw("Query cdna isn't a Bio::Seq or Bio::PrimarySeq");
        }
        $self->{'_query_cdna'} = $seq ;
    }
    return $self->{'_query_cdna'};
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
    Function:   Runs pseudowise and creates array of sub-seqfeatures
    Returns :   none
    Args    :   none

=cut

sub run {

    my ($self) = @_;
    #check seq
    my $seq1 = $self->query_pep() || $self->throw("Query protein sequence required for Genscan\n");
    my $seq2 = $self->query_cdna() || $self->throw("Query cdna sequence  required for Genscan\n");
    my $seq3 = $self->target_dna() || $self->throw("Target dna sequence required for Genscan\n");
    #run pseudowise       
    my $factory = Bio::Tools::Run::Pseudowise->new();
    my @genes;
    eval {
      @genes = $factory->predict_genes($seq1, $seq2, $seq3);
    };
    $self->output(\@genes);
    return \@genes;
 }
  
=head2 output

Title   :   output
Usage   :   $self->output($seq)
Function:   Get/set method for output
Returns :   An array of Bio::Search::HSP::GenericHSP objects
Args    :   An array ref to an array of Bio::Search::HSP::GenericHSP objects

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
	



