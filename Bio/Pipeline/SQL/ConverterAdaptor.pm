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
use Bio::Pipeline::Method;
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
   return unless(defined $converter->method);

	foreach my $converter_method (@{$converter->method}) {
		$self->_store_converter_method($converter_method, $converter->dbID);
	}

#	$self->{_cache}->{$converter->dbID} = $converter;
}

sub _store_converter_method{
	my ($self, $converter_method, $converter_id) = @_;

	if(defined ($converter_method->dbID)){
		my $sql = "INSERT INTO converter_methods SET converter_method_id=?, converter_id=?, name=?, rank=?";
		my $sth = $self->prepare($sql);
      $sth->execute( 
			$converter_method->dbID, 
			$converter_id, 
			$converter_method->name, 
			$converter_method->rank);
	}else{
		my $sql = "INSERT INTO converter_methods SET converter_id=?, name=?, rank=?";
		my $sth = $self->prepare($sql);
		$sth->execute($converter_id, 
			$converter_method->name, 
			$converter_method->rank);
		$converter_method->dbID($sth->{mysql_insertid});
	}
   
	my $converter_arguments_ref = $converter_method->arguments;
	return if(!defined($converter_arguments_ref));

	foreach my $converter_argument (@{$converter_arguments_ref}) {
		$self->_store_converter_argument($converter_argument, $converter_method->dbID);
	}

}

sub _store_converter_argument{
	my ($self, $converter_argument, $converter_method_id) = @_;
   $converter_method_id || $self->throw("a method id needed");
	if(defined ($converter_argument->dbID)){
		my $sql = "INSERT INTO converter_arguments SET converter_argument_id=?, converter_method_id=?, tag=?, value=?, rank=?";
		my $sth = $self->prepare($sql);
      $sth->execute( 
			$converter_argument->dbID, 
			$converter_method_id, 
			$converter_argument->tag, 
			$converter_argument->value, 
			$converter_argument->rank);
	}else{
		my $sql = "INSERT INTO converter_arguments SET converter_method_id=?, tag=?, value=?, rank=?";
		my $sth = $self->prepare($sql);
		$sth->execute($converter_method_id, 
			$converter_argument->tag, 
			$converter_argument->value, 
			$converter_argument->rank);
		$converter_argument->dbID($sth->{mysql_insertid});
	}
}

=head2 fetch_by_dbID 


=cut

sub fetch_by_dbID{
	my ($self, $id, @other_params) = @_;
	if(defined $self->{_cache}->{$id}){
		return $self->{_cache}->{$id};
	}

	my $query = "SELECT converter_id, module FROM converters WHERE converter_id = $id";
	
	my $sth = $self->prepare($query);
    $sth->execute();
#	my ($converter_id, $module, $method, $rank, $argument) = $sth->fetchrow_array;
	my ($converter_id, $module) = $sth->fetchrow_array;	

    $module = "Bio::Pipeline::Converter::$module";
   
    $self->_load_module($module);   

    my $methods_ref = $self->_fetch_converter_method_by_converter_dbID($converter_id);

    my @new_arguments = ();
    my @methods = @{$methods_ref};
    my $first_method = shift @methods;
    if($first_method->name eq 'new'){
       @new_arguments = @{$self->_format_converter_new_arguments($first_method->arguments)};
    }

    my @new_params = ();
    push @new_params, -dbID => $converter_id;
    push @new_params, -module => $module;
    push @new_params, -method => $methods_ref;
    push @new_params, @other_params;
    push @new_params, @new_arguments;
    
	my $converter = "$module"->new(@new_params);

	$self->{_cache}->{$id} = $converter;

	return $converter;
}

sub _fetch_converter_method_by_converter_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT converter_method_id, name, rank FROM converter_methods WHERE converter_id = $id";
	my $sth = $self->prepare($query);
	$sth->execute();
	my @methods;
	while(my ($converter_method_id, $name, $rank) = $sth->fetchrow_array){
		my $arguments_ref = $self->_fetch_arguments_by_method_dbID($converter_method_id);
		
		my $converter_method = new Bio::Pipeline::Method(
			-dbID => $converter_method_id,
			-name => $name,
			-rank => $rank,
			-argument => $arguments_ref
		);
		push  @methods , $converter_method;
	}	
	return \@methods;
}

sub _fetch_arguments_by_method_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT converter_argument_id, tag, value, rank FROM converter_arguments WHERE converter_method_id = $id";

	my $sth = $self->prepare($query);
	$sth->execute;
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

sub _format_converter_new_arguments{
    my ($self, $arguments_ref) = @_;
    my @argument_objs;
    @argument_objs = sort {$a->rank <=> $b->rank} @{$arguments_ref};
    my @arguments;
#    print "\n" . scalar @argument_objs . "\n";
    my $value;

    for(my $i=0; $i <= $#argument_objs; $i++){
        my $tag = $argument_objs[$i]->tag;
        my $value = $argument_objs[$i]->value;
#        print "$tag\t$value\n";
        if(defined $tag){
            push @arguments, ($tag => $value);
        }else{
            push @arguments, $value;
        }

    }

    return \@arguments;
    
    
}

1;
