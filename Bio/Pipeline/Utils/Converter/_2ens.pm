
package Bio::Pipeline::Converter::_2ens;

use vars qw(@ISA);

use strict;
# use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);  
    my ($dbname, $host, $driver, $user, $pass, $contig_dbID) =
        $self->_rearrange([qw( DBNAME HOST DRIVER USER PASS CONTIG_DBID)], @args);


   my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user => $user,
      -dbname => $dbname,
      -host => $host,
      -driver => $driver,
      -pass => $pass
   );
	
    $self->ens_dbadaptor($dba);
    $contig_dbID ||= 0; # $self->throw("contig_dbID is needed");
    $self->contig_dbID($contig_dbID);		
    return $self;
}

sub ens_dbadaptor{
   my ($self, $arg) = @_;
   if(defined $arg){
       $self->{"_ens_dbadaptor"} = $arg;
   }
   return $self->{"_ens_dbadaptor"};
}

sub contig_dbID{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{"_contig_dbid"} = $arg;
    }
    return $self->{"_contig_dbid"};
}

sub contig_name{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{"_contig_name"} = $arg;
    }
    return $self->{"_contig_name"};
}

1;
