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
use Bio::Pipeline::DataHandler;
use Bio::Pipeline::Argument;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);


sub store {
    my ($self,$converter) = @_;


    if (!defined ($converter->dbID)) {
	my $sth = $self->prepare( q{
	    INSERT INTO converters 
		SET module =?} );

	$sth->execute
	    ( $converter->module);
        my $dbid = $sth->{mysql_insertid};
        $converter->dbID($dbid);
    } else {
        my $sth = $self->prepare( q{
            INSERT INTO converters
                SET converter_id = ?, 
                    module = ?
            } );

        $sth->execute
            ( $converter->dbID,
              $converter->module
            );
    }

	foreach my $converter_method (@{$converter->method}) {
		$self->_store_converter_method($converter_method, $converter->dbID);
	}

	$self->{_cache}->{$converter->dbID} = $converter;
}

sub _store_converter_method{
	my ($self, $converter_method, $converter_id) = @_;

	if(defined ($converter_method->dbID)){
		my $sql = "INSERT INTO converter_methods SET converter_method_id=?, converter_id=?, method=?, rank=?";
		$self->prepare_execute($sql, 
			$converter_method->dbID, 
			$converter_id, 
			$converter_method->method, 
			$converter_method->rank);
	}else{
		my $sql = "INSERT INTO converter_methods SET converter_id=?, method=?, rank=?";
		my $sth = $self->prepare($sql);
		$sth->execute($converter_id, 
			$converter_method->method, 
			$converter_method->rank);
		$converter_method->dbID($sth->{mysql_inserted});
	}

	my $converter_arguments_ref = $converter_method->argument;
	return if(!defined($converter_arguments_ref));

	foreach my $converter_argument (@{$converter_arguments_ref}) {
		$self->_store_converter_argument($converter_argument, $converter_method->dbID);
	}

}

sub _store_converter_argument{
	my ($self, $converter_argument, $converter_method_id) = @_;

	if(defined ($converter_argument->dbID)){
		my $sql = "INSERT INTO converter_arguments SET converter_argument_id=?, converter_method_id=?, tag=?, value=?, rank=?";
		$self->prepare_execute($sql, 
			$converter_argument->dbID, 
			$converter_method_id, 
			$converter_argument->tag, 
			$converter_argument->value, 
			$converter_argument->rank);
	}else{
		my $sql = "INSERT INTO converter_arguments SET converter_method_id=?, tag=?, value=?";
		my $sth = $self->prepare($sql);
		$sth->execute($converter_method_id, 
			$converter_argument->tag, 
			$converter_argument->value, 
			$converter_argument->rank);
		$converter_argument->dbID($sth->{mysql_inserted});
	}
}

sub fetch_by_dbID{
	my ($self, $id) = @_;
	if(defined $self->{_cache}->{$id}){
		return $self->{_cache}->{$id};
	}

	my $query = "SELECT converter_id, module FROM converters WHERE converter_id = $id";
	
	my $sth = $self->prepare_execute($query);
	my ($converter_id, $module, $method, $rank, $argument) = $sth->fetchrow_array;
	
	my $methods_ref = $self->_fetch_converter_method_by_converter_dbID( $converter_id);

	my $converter = new Bio::Pipeline::Converter(
		-dbID => $converter_id,
		-module => $module,
		-method => $methods_ref,
#		-rank => $rank,
#		-argument => $argument
	);

	$self->{_cache}->{$id} = $converter;

	return $converter;
}

sub _fetch_converter_method_by_converter_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT converter_method_id, method, rank FROM converter_methods WHERE converter_id = $id";
	my $sth = $self->prepare_execute($query);
	
	my @methods;
	while(my ($converter_method_id, $method, $rank) = $sth->fetchrow_array){
		my $arguments_ref = $self->_fetch_converter_argument_by_converter_method_dbID($converter_method_id);
		
		my $converter_method = new Bio::Pipeline::DataHandler(
			-dbID => $converter_method_id,
			-method => $method,
			-rank => $rank,
			-argument => $arguments_ref
		);
		
		push  @methods , $converter_method;
	}	

	return \@methods;
}

sub _fetch_converter_argument_by_converter_method_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT converter_argument_id, tag, value, rank FROM converter_arguments WHERE converter_method_id = $id";

	my $sth = $self->prepare_execute($query);
	
	my @arguments;

	while(my ($converter_argument_id, $tag, $value, $rank) = $sth->fetchrow_array){
		my $converter_argument = Bio::Pipeline::Argument->new (
			-dbID => $converter_argument_id,
			-tag => $tag,
			-value => $value,
			-rank => $rank
		);

		push @arguments, $converter_argument;
	}

	return \@arguments;
}

1;
