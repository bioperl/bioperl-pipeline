
package Bio::Pipeline::Converter::_2ens;

use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);  
    my ($dbname, $host, $driver, $user, $pass) =
      $self->_rearrange([qw( DBNAME HOST DRIVER USER PASS )], @args);

   my $dba = new Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user => $user,
      -dbname => $dbname,
      -host => $host,
      -driver => $driver
   );
	
   $self->ens_dbadaptor($dba);
   return $self;
}

sub ens_dbadaptor{
   my ($self, $arg) = @_;
   if(defined $arg){
       $self->{"_ens_dbadaptor"} = $arg;
   }
   return $self->{"_ens_dbadaptor"};
}

1;
