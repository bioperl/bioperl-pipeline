#doesn't do anything. Used for testing pipeline
package Bio::Pipeline::Runnable::TestRunnable;

use vars qw(@ISA);
use strict;
use Bio::Pipeline::RunnableI;
use Bio::SeqFeature::Generic;
use Bio::SeqIO;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->{'_output'} = []; 
    return $self;
}
sub seq {
    my ($self,$value) = @_;
    if ($value){
        $self->{'_seq'} = $value;
    }
    return $self->{'_seq'};
}
sub datatypes {
    my ($self) = @_;

    my $dt = Bio::Pipeline::DataType->new(-object_type=>"Bio::PrimarySeqI",
                                          -name=>"sequence",
                                          -reftype=>"SCALAR");
    my %dt;
    $dt{seq} = $dt;
    return %dt;
}
sub run {
    my ($self) = @_;
    my $seq = $self->seq();
    $seq || $self->throw("Input seq not set!");
    my $rev = $seq->revcom;
    $self->output($rev);
}

sub output {
    my ($self,$seq) = @_;
    if ($seq){
       $self->{'_output'} = $seq;
   }
   return $self->{'_output'};
}
1;

