
package Bio::Pipeline::Converter::featurePair_bio2ens;


use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub ens_dbadaptor{
   my ($self, @args) = @_;

   my ($dbname, $host, $driver, $user, $pass) =
      $self->_rearrange([qw( DBNAME HOST DRIVER USER PASS )], @args);

   my $dba = new Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user => $user,
      -dbname => $dbname,
      -host => $host,
      -driver => $driver
   );

   $self->{"_ens_dba"} = $dba;

   return $dba;
}

sub convert{

	my ($self, $args) = @_;

	my $converter = Bio::SeqFeatureIO->new(
		'-in' => 'Bio::SeqFeature::FeaturePair',
		'-out' => 'Bio::EnsEMBL::FeaturePair'
	);
		
	return $converter->convert($args);
}
1;
