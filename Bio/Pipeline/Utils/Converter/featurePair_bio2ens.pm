
package Bio::Pipeline::Converter::featurePair_bio2ens;


use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub converter{

	my ($self, @args) = @_;

	my $converter = Bio::SeqFeatureIO->new(
		'-in' => 'Bio::SeqFeature::FeaturePair',
		'-out' => 'Bio::EnsEMBL::FeaturePair'
	);
		
	return $converter->convert(@args);
}
1;