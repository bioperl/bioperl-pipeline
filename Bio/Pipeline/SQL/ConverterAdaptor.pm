# Perl module for Bio::EnsEMBL::Pipeline::DBSQL::ConverterAdaptor
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
# Last modified : 05.09.2000 by Arne Stabenau
#
# Copyright EMBL-EBI 2000
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::DBSQL::ConverterAdaptor

=head1 SYNOPSIS

  $analysisAdaptor = $dbobj->getConverterAdaptor;
  $analysisAdaptor = $analysisobj->getConverterAdaptor;


=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class Converter.
  There should be just one per application and database connection.


=head1 CONTACT

    Kiran: kiran@fugu-sg.org
    Shawn: shawnh@fugu-sg.org
    Juguang: juguang@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::SQL::ConverterAdaptor;

use Bio::Pipeline::Converter;
use Bio::Pipeline::SQL::BaseAdaptor;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);


sub store {
    my ($self,$converter) = @_;


    if (!defined ($converter->dbID)) {
	my $sth = $self->prepare( q{
	    INSERT INTO converter 
		SET module = ?,
		    method = ? } );

	$sth->execute
	    ( $converter->module,
	      $converter->method );
        my $dbid = $sth->{mysql_insertid};
        $converter->dbID($dbid);
    } else {
        my $sth = $self->prepare( q{
            INSERT INTO converter
                SET converter_id = ?, 
                    module = ?,
                    method = ? } );

        $sth->execute
            ( $converter->dbID,
              $converter->module,
              $converter->method );
    }
	$self->{_cache}->{$converter->dbID} = $converter;
}

sub fetch_by_dbID{
	my ($self, $id) = @_;
	if(defined $self->{_cache}->{$id}){
		return $self->{_cache}->{$id};
	}

	my $query = "SELECT converter_id, module, method, argument FROM converter WHERE converter_id = $id";
	
	my $sth = $self->prepare_execute($query);
	my ($converter_id, $module, $method, $argument) = $sth->fetchrow_array;
	
	my $converter = new Bio::Pipeline::Converter(
		-dbID => $converter_id,
		-module => $module,
		-method => $method,
		-argument => $argument
	);

	$self->{_cache}->{$id} = $converter;

	return $converter;
}

1;
