
package Bio::Pipeline::Converter::gene_bio2ens;

use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub converter{

	my ($self, @args) = @_;

	my $converter = Bio::SeqFeatureIO->new(
		'-in' => 'Bio::SeqFeature::Gene::GeneStructure',
		'-out' => 'Bio::EnsEMBL::Gene'
	);
		
	return $converter->convert(@args);
}
1;