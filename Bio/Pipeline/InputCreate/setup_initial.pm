package Bio::Pipeline::InputCreate::setup_initial;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($initial_ioh) = $self->_rearrange([qw(INITIAL_IOH)],@args);

    $initial_ioh|| $self->throw("Need an iohandler to setup initial jobs");
    $self->initial_ioh($initial_ioh);

}

sub initial_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_initial_ioh'} = $arg;
    }
    return $self->{'_initial_ioh'};
}

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'',
                                          '-name'=>'ids',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

sub run {
    my ($self,$next_anal,@input) = @_;
    
    #check the first is enuff?
    $#input> 0 || return;
    
    #shawn to fix--creating input for contig_start_end
    foreach my $input(@input){
        
        my $input1 = $self->create_input($input,$self->initial_ioh);

        my $job = $self->create_job($next_anal,[$input1]);

        $self->dbadaptor->get_JobAdaptor->store($job);
        
    }
        
    
}

1;
    



