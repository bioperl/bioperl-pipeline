# perl module for Bio::Pipeline::SQL::TransformerAdaptor
#
# Creator: Fugu Team <fuguteam@fugu-sg.org>
# Date of creation: 19.02.2003
#
# Copyright IMCB 2003
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::DBSQL::TransformerAdaptor

=head1 SYNOPSIS

  $transformerAdaptor = $dbobj->getTransformerAdaptor;


=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class transformer.
  There should be just one per application and database connection.


=head1 CONTACT

    Kiran: kiran@fugu-sg.org
    Shawn: shawnh@fugu-sg.org
    Juguang: juguang@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::SQL::TransformerAdaptor;

use Bio::Pipeline::Transformer;
use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::Method;
use Bio::Pipeline::Argument;

use vars qw(@ISA);
use strict;

@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);

=head2 store

  Title   : store
  Usage   : 
    my ($transformer1, $transformer2);
    $transformer->store[$transformer1, $transformer2]);
    (
  Function: Stores a array of transformer objects into the db. 
  Returns : None (dbIDs of transformers would be stored inside of transformers.)
  Args    : L<Bio::Pipeline::Transformer>

=cut

sub store {
    my ($self, $transformer) = @_;

    unless(ref($transformer) eq 'ARRAY'){
        $self->warn("An array ref wanted: TransformerAdaptor::store");
        return $self->_store_single($transformer);
    }
    
    foreach(@{$transformer}){
        $self->_store_single($_);
    }
}

# NOTE: No return value from this method, since we follow the EnsEMBL adaptor's
# store method conventions, e.g. No return dbID, but assign the dbID into the 
# object.

# stores transformer module into transformer table

sub _store_single {
    my ($self,$transformer) = @_;

    $self->throw("A Bio::Pipeline::Transformer needed")
        unless ($transformer->isa('Bio::Pipeline::Transformer'));
        
    if (!defined ($transformer->dbID)) {
    	my $sth = $self->prepare( q{
	                               INSERT INTO transformer 
                              	 SET module =?} );

    	$sth->execute( $transformer->module) || $self->throw("Unable to insert into transformer table");
      my $dbid = $sth->{mysql_insertid};
      $transformer->dbID($dbid);
    } 
    else {
        my $sth = $self->prepare( q{
                                   INSERT INTO transformer
                                   SET transformer_id = ?, 
                                   module = ?
                                  } );

        $sth->execute($transformer->dbID,$transformer->module) || $self->throw("Unable to insert into transformer table");
    }
    $transformer->adaptor($self);
    
   if($transformer->method) {
         my @methods = @{$transformer->method};
      	 foreach my $transformer_method (@methods) {
    	     $self->_store_transformer_method($transformer_method, $transformer->dbID);
	       }
   }
   else {
    $self->warn("Storing Transformer without methods!");
   }
}

#store method information into transformer_method table
sub _store_transformer_method{
	my ($self, $transformer_method, $transformer_id) = @_;

	if(defined ($transformer_method->dbID)){
		my $sql = "INSERT INTO transformer_method SET transformer_method_id=?, transformer_id=?, name=?, rank=?";
		my $sth = $self->prepare($sql);
      $sth->execute( 
			$transformer_method->dbID, 
			$transformer_id, 
			$transformer_method->name, 
			$transformer_method->rank);
	}else{
		my $sql = "INSERT INTO transformer_method SET transformer_id=?, name=?, rank=?";
		my $sth = $self->prepare($sql);
		$sth->execute($transformer_id, 
			$transformer_method->name, 
			$transformer_method->rank);
		$transformer_method->dbID($sth->{mysql_insertid});
	}
   
  if($transformer_method->arguments){
  	foreach my $transformer_argument (@{$transformer_method->arguments}) {
		  $self->_store_transformer_argument($transformer_argument, $transformer_method->dbID);
	  }
  }
  return $transformer_method->dbID;

}

#store argument information into transformer_method table
sub _store_transformer_argument{
	my ($self, $transformer_argument, $transformer_method_id) = @_;
   $transformer_method_id || $self->throw("a method id needed");
	if(defined ($transformer_argument->dbID)){
		my $sql = "INSERT INTO transformer_argument SET transformer_argument_id=?, transformer_method_id=?, tag=?, value=?, rank=?";
		my $sth = $self->prepare($sql);
      $sth->execute( 
			$transformer_argument->dbID, 
			$transformer_method_id, 
			$transformer_argument->tag, 
			$transformer_argument->value, 
			$transformer_argument->rank);
	}else{
		my $sql = "INSERT INTO transformer_argument SET transformer_method_id=?, tag=?, value=?, rank=?";
		my $sth = $self->prepare($sql);
		$sth->execute($transformer_method_id, 
            			$transformer_argument->tag, 
            			$transformer_argument->value, 
            			$transformer_argument->rank);
   $transformer_argument->dbID($sth->{mysql_insertid});
	}
}

=head2 fetch_by_dbID

  Title   : fetch_by_dbID
  Usage   : $transformer->fetch_by_dbID($id)
  Function: fetches the transformer object using a dbID 
  Returns : L<Bio::Pipeline::Transformer>
  Args    : A dbID

=cut

sub fetch_by_dbID{
	my ($self, $id ) = @_;
	if(defined $self->{_cache}->{$id}){
		return $self->{_cache}->{$id};
	}

  my $query = "SELECT transformer_id, module FROM transformer WHERE transformer_id = $id";
	
	my $sth = $self->prepare($query);
  $sth->execute();
	my ($transformer_id, $module) = $sth->fetchrow_array;	

  $self->_load_module($module);   

    my $methods_ref = $self->_fetch_transformer_method_by_transformer_dbID($transformer_id);

    my @new_arguments = ();
    my @methods = @{$methods_ref};
    my $first_method = shift @methods;

    my @new_params = ();
    push @new_params, -dbID => $transformer_id;
    push @new_params, -module => $module;
    push @new_params, -method => $methods_ref;
    
	my $transformer = Bio::Pipeline::Transformer->new(@new_params);

	$self->{_cache}->{$id} = $transformer;

	return $transformer;
}

sub _fetch_transformer_method_by_transformer_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT transformer_method_id, name, rank FROM transformer_method WHERE transformer_id = $id";
	my $sth = $self->prepare($query);
	$sth->execute();
	my @methods;
	while(my ($transformer_method_id, $name, $rank) = $sth->fetchrow_array){
		my $arguments_ref = $self->_fetch_arguments_by_method_dbID($transformer_method_id);
		
		my $transformer_method = new Bio::Pipeline::Method(
			-dbID => $transformer_method_id,
			-name => $name,
			-rank => $rank,
			-argument => $arguments_ref
		);
		push  @methods , $transformer_method;
	}	
	return \@methods;
}

sub _fetch_arguments_by_method_dbID{
	my ($self, $id) = @_;
	
	my $query = "SELECT transformer_argument_id, tag, value, rank FROM transformer_argument WHERE transformer_method_id = $id";

	my $sth = $self->prepare($query);
	$sth->execute;
	my @arguments;

	while(my ($transformer_argument_id, $tag, $value, $rank) = $sth->fetchrow_array){
		my $transformer_argument = Bio::Pipeline::Argument->new (
			-dbID => $transformer_argument_id,
			-tag => $tag,
			-value => $value,
			-rank => $rank
		);
		push @arguments, $transformer_argument;
	}
	return \@arguments;
}

sub _format_transformer_new_arguments{
    my ($self, $arguments_ref) = @_;
    my @argument_objs;
    @argument_objs = sort {$a->rank <=> $b->rank} @{$arguments_ref};
    my @arguments;
    my $value;

    for(my $i=0; $i <= $#argument_objs; $i++){
        my $tag = $argument_objs[$i]->tag;
        my $value = $argument_objs[$i]->value;
        if(defined $tag){
            push @arguments, ($tag => $value);
        }else{
            push @arguments, $value;
        }

    }

    return \@arguments;
}

1;
