package Bio::Pipeline::IO;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbadaptor,$analysis,$biodbadaptor,$biodbname,
      $data_adpt,$data_adpt_method) = $self->_rearrange([qw(DBADAPTOR
                                                            ANALYSIS
                                                            BIODBADAPTOR
                                                            BIODBNAME
                                                            DATAADAPTOR
                                                            DATAADAPTORMETHOD)],@args);
  $dbadaptor || $self->throw("Need a dbadaptor");
  $analysis || $self->throw("Need an analysis");
  $data_adpt || $self->throw("Need a data adaptor");
  $data_adpt_method || $self->throw("Need a data adaptor method");

  $self->dbadaptor($dbadaptor);
  $self->data_adaptor($data_adpt);
  $self->data_adaptor_method($data_adpt_method);
  
  if($biodbadaptor && $biodbname) {
    $self->bio_dbadaptor($biodbadaptor);
    $self->bio_dbname($biodbname);
  }
  elsif((!$biodbadaptor &&$biodbname) || (!$biodbname && $biodbadaptor)){
    $self->throw("Both biodbadaptor and biodbanme must be specified.");
  }
  else {}

  return $self;
}    
sub dbadaptor {
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_dbadaptor'} = $adaptor;
    }
    return $self->{'_dbadaptor'};
}
sub analysis {
    my ($self,$analysis) = @_;
    if (defined $analysis) {
        $self->{'_analysis'} = $analysis;
    }
    return $self->{'_analysis'};
}

sub bio_dbadaptor {
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_bio_dbadaptor'} = $adaptor;
    }
    return $self->{'_bio_dbadaptor'};
}

sub data_adaptor {
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_data_adaptor'} = $adaptor;
    }
    return $self->{'_data_adaptor'};
}
sub data_adaptor_method {
    my ($self,$method) = @_;
    if (defined $method) {
        $self->{'_data_adaptor_method'} = $method;
    }
    return $self->{'_data_adaptor_method'};
}

sub bio_dbname {
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{'_bio_dbname'} = $arg;
    }
    return $self->{'_bio_dbname'};
}
    
sub bio_adaptor{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{'_bio_adaptor_id'} = $arg;
    }
    return $self->{'_bio_adaptor_id'};
}
1;



    
          
