package Bio::Pipeline::Utils::MaskSeq;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $MaskSeq = Bio::Pipeline::Utils::MaskSeq->new('-module'=>$module);
  Function: constructor for MaskSeq object 
  Returns : a new MaskSeq object 
  Args    : module, the list of MaskSeq modules found in Bio::Pipeline::Utils::MaskSeq::*

=cut

sub new {
    my ($caller ,@args) = @_;
    my $class = ref($caller) || $caller;
    my ($self) = $class->SUPER::new(@args);
    return $self;
}

sub run {
    my ($self,$contig) = @_;
    $self->throw("Not an Ensembl Contig") unless ($contig->isa("Bio::EnsEMBL::RawContig") || $contig->isa("Bio::EnsEMBL::Slice"));
    return $contig->get_repeatmasked_seq;
}
1;
