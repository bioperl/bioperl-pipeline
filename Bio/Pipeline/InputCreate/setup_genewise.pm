package Bio::Pipeline::InputCreate::setup_genewise;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($contig_ioh,$protein_ioh,$dh_ioh) = $self->_rearrange([qw(CONTIG_IOH PROTEIN_IOH DATA_HANDLER_ID)],@args);

    $contig_ioh || $self->throw("Need an iohandler for the contig");
    $self->contig_ioh($contig_ioh);

    $protein_ioh || $self->throw("Need an iohandler for the protein");
    $self->protein_ioh($protein_ioh);

    $dh_ioh || $self->throw("Need an datahandler id for fetch_contig_start_end method");
    $self->dhid($dh_ioh);

}

sub contig_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_contig_ioh'} = $arg;
    }
    return $self->{'_contig_ioh'};
}

sub protein_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_protein_ioh'} = $arg;
    }
    return $self->{'_protein_ioh'};
}
sub dhid {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_dhid'} = $arg;
    }
    return $self->{'_dhid'};
}

sub new_ioh {
    my ($self,$ioh) = @_;
    if($ioh) {
        $self->{'_new_ioh'} = $ioh;
    }
    return $self->{'_new_ioh'};
}

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqFeatureI',
                                          '-name'=>'sequence',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

sub run {
    my ($self,$next_anal,@output) = @_;
    
    #check the first is enuff?
    $#output > 0 || return;
    $output[0]->isa("Bio::SeqFeatureI") || $self->throw("Need a SeqFeatureI object to setup_genewise");
    my $chr = $output[0]->entire_seq->db_handle->get_Contig($output[0]->entire_seq->display_id)->chromosome;
    
    #shawn to fix--creating input for contig_start_end
    foreach my $output(@output){
        my $contig_name  = $output->seqname;
        my $contig_start = $output->feature1->start;
        my $contig_end   = $output->feature1->end;
        my $protein_id   = $output->hseqname;
        
        my $input1 = $self->create_input($protein_id,$self->protein_ioh);

        my @arg;
        my $arg = Bio::Pipeline::Argument->new(-rank=>1,-value=>$chr,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;
        $arg = Bio::Pipeline::Argument->new(-rank=>2,-value=>$contig_start,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;
        $arg = Bio::Pipeline::Argument->new(-rank=>3,-value=>$contig_end,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;

        my $input2 = Bio::Pipeline::Input->new(-name=>$contig_name,-input_handler=>$self->contig_ioh,-dynamic_arguments=>\@arg);

        my $job = $self->create_job($next_anal,[$input1,$input2]);

        $self->dbadaptor->get_JobAdaptor->store($job);
        
    }
        
    
}

1;
    



