
package Bio::Pipeline::Converter::_2ens;

use vars qw(@ISA);

use strict;
# use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);  
    my ($dbname, $host, $driver, $user, $pass, $contig_dbID, $analysis_logic_name) =
        $self->_rearrange([qw( DBNAME HOST DRIVER USER PASS CONTIG_DBID ANALYSIS_LOGIC_NAME)], @args);

   require "Bio/EnsEMBL/DBSQL/DBAdaptor.pm";
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
    $analysis_logic_name && $self->analysis_logic_name($analysis_logic_name);
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

sub analysis_logic_name{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_logic_name($arg);
        $self->analysis($analysis);
        $self->{'_analysis_logic_name'} = $arg;
    }
    return $self->{'_analysis_logic_name'};
}

sub analysis{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{'_analysis'} = $arg;
    }
    return $self->{'_analysis'};
}

1;
