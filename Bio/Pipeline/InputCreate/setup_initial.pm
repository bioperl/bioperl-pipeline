package Bio::Pipeline::InputCreate::setup_initial;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);
   
    #from here on, assume all parameters are for iohandler mapping
    $#args > 0 || $self->throw("Need iohandlers to setup initial jobs"); 
    my %ioh = @args;
    @ioh{ map { lc $_ } keys %ioh} = values %ioh; # lowercase keys

    $self->iohandler_map(\%ioh);


}

sub iohandler_map {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_iohandler_map'} = $arg;
    }
    return $self->{'_iohandler_map'};
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
    my ($self,$next_anal,$input) = @_;

    (ref($input) eq "HASH") || $self->throw("Expecting a hash reference");
    my $ioh_map = $self->iohandler_map;

    foreach my $key (keys %{$input}){
#       $key = lc $key;
       my $ioh = $ioh_map->{$key};
       if(!$input->{$key}){
           $self->throw("Iohandler map for $key does not have inputs");
       }
       my @input;
       if(ref $input->{$key} eq "ARRAY"){
        @input = @{$input->{$key}};
       }
       else {
        push @input, $input->{$key};
       }

       foreach my $in(@input){
        my $input1 = $self->create_input($in,$ioh);

        my $job = $self->create_job($next_anal,[$input1]);

        $self->dbadaptor->get_JobAdaptor->store($job);
       }
        
    }
        
    
}

1;
    



